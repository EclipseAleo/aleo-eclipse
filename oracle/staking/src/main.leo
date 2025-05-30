////////////////////////////////////////////////////////////////////////////////
// Eclipse Oracle – Staking v2
//
// Author : **Florent Gaujal** <https://github.com/floflo777>
// Date   : 2025-05-10
//
// ### Purpose
// Manages **token staking** for price-feed providers.
//
// A provider must lock ALEO-native tokens (via `token_registry.aleo`) to be
// eligible for submitting prices and/or aggregating.  Staking enforces:
// - an economic floor (`min_stake`) per provider,
// - a **maximum** of `MAX_PROVIDERS` active providers per feed,
// - the ability to *slash* misbehaving providers (called by the
//   `Aggregate` contract),
// - basic membership management (`add_provider`).
//
// ### Storage
// | Mapping          | Key                      | Value   | Description                               |
// |------------------|--------------------------|---------|-------------------------------------------|
// | `total_staked`   | `feed_id`                | `u128`  | Sum of all stakes for a feed              |
// | `stakes`         | `feed_id‖provider`       | `u128`  | Current stake of a provider               |
// | `provider_count` | `feed_id`                | `u32`   | Number of active providers                |
// | `provider_list`  | `feed_id‖slot(0-7)`      | address | Up to 8 providers stored contiguously     |
//
// ### Invariants
// - `stake ≥ min_stake` for all active providers.
// - `provider_count ≤ MAX_PROVIDERS`.
// - No duplicates in `provider_list`.
// - `total_staked` equals the sum of non-zero `stakes`.

// ---------------------------------------------------------------------------
//  External dependencies
// ---------------------------------------------------------------------------
import eclipse_oracle_feed.aleo;     
import token_registry.aleo;         

program eclipse_oracle_staking_3.aleo {

    // --------------------------------------------------------------------
    //  Constants
    // --------------------------------------------------------------------
    const MAX_PROVIDERS: u32 = 8u32;                // Hard cap per feed
    const TOKEN_ID: field = 1234567898field;    // reward token ID

    // Feed config
    struct FeedConfig {
        creator: address,
        min_stake: u64,
        slashing_threshold: u64,
        aggregation_window: u32,
        challenge_window: u32,
        paused: bool
    }

    // --------------------------------------------------------------------
    //  Persistent storage
    // --------------------------------------------------------------------
    mapping total_staked: field => u128;   // Σ stakes for a given feed
    mapping stakes: field => u128;   // Individual stake per provider
    mapping provider_count: field => u32;    // Number of active providers
    mapping provider_list:  field => address;// Compact array of providers

    // ====================================================================
    // 1. Stake
    // ====================================================================
    //
    // Locks public tokens into the contract (public → private transfer in
    // `token_registry.aleo`).  First-time stakers must comply with
    // `cfg.min_stake`.  A provider is added to `provider_list` if there is
    // room; otherwise, they must replace the currently *smallest* staker
    // (see `add_provider`).
    //
    async transition stake(
        public feed_id: field,
        public amount: u128,
        public caller: address
    ) -> Future {
        let fut: Future =
            token_registry.aleo/transfer_public_as_signer(
                TOKEN_ID,
                eclipse_oracle_staking_3.aleo,
                amount              
            );
        return finalize_stake(fut, feed_id, amount, caller);
    }

    /// Continuation after the async transfer settles.
    async function finalize_stake(
        fut: Future,
        public feed_id: field,
        public amount:  u128,
        public caller:  address
    ) {
        fut.await();                                         

        let cfg: FeedConfig = eclipse_oracle_feed.aleo/feeds.get(feed_id);
        assert(!cfg.paused);                                 
        assert(amount > 0u128);                               

        // Composite key: feed_id || provider address
        let key: field = feed_id + (caller as field);
        let prev: u128 = stakes.get_or_use(key, 0u128);

        // A *new* provider must stake at least the minimum.
        if (prev == 0u128) {
            assert(amount >= cfg.min_stake as u128);
        }

        // Update individual & total stake
        let new_stake: u128 = prev + amount;
        stakes.set(key, new_stake);

        let prev_total: u128 = total_staked.get_or_use(feed_id, 0u128);
        total_staked.set(feed_id, prev_total + amount);

        // ----------------------------------------------------------------
        // Register provider in the list if not already present
        // ----------------------------------------------------------------
        let count: u32 = provider_count.get_or_use(feed_id, 0u32);

        if (prev == 0u128 && count < MAX_PROVIDERS) {
            // Ensure uniqueness
            for i: u32 in 0u32..MAX_PROVIDERS {
                if (i < count) {
                    let key_i: field = feed_id + (i as field);
                    let p: address = provider_list.get(key_i);
                    assert(p != caller);
                }
            }
            // Append at position `count`
            let new_key: field = feed_id + (count as field);
            provider_list.set(new_key, caller);
            provider_count.set(feed_id, count + 1u32);
        }
    }

    // ====================================================================
    // 2. Withdraw
    // ====================================================================
    //
    // Releases a portion (or all) of a provider’s stake back to a *public*
    // balance. In later versions, providers will have to keep ≥ `min_stake`, unless fully exiting.
    //
    async transition withdraw(
        public feed_id: field,
        public amount: u128,
        public caller: address
    ) -> Future {
        let fut: Future = token_registry.aleo/transfer_public(
            TOKEN_ID,
            caller,
            amount
        );
        return finalize_withdraw(fut, feed_id, amount, caller);
    }

    async function finalize_withdraw(
        fut: Future,
        public feed_id: field,
        public amount: u128,
        public caller: address
    ) {
        fut.await();                                           
        let cfg: FeedConfig = eclipse_oracle_feed.aleo/feeds.get(feed_id);
        assert(!cfg.paused);
        assert(amount > 0u128);

        let key: field = feed_id + (caller as field);
        let prev: u128 = stakes.get(key);
        assert(prev >= amount);                              

        let new_stake: u128 = prev - amount;
        // If still active, enforce min_stake
        assert(new_stake == 0u128 || new_stake >= cfg.min_stake as u128);

        stakes.set(key, new_stake);

        let prev_total: u128 = total_staked.get_or_use(feed_id, 0u128);
        total_staked.set(feed_id, prev_total - amount);
    }

    // ====================================================================
    // 3. Slash (called by Aggregate contract)
    // ====================================================================
    //
    // Burns an entire provider’s stake as punishment.  Only
    // `eclipse_oracle_aggregate_2.aleo` can invoke this entry point.
    //
    async transition slash(
        public feed_id: field,
        public provider: address
    ) -> Future {
        assert(self.caller == eclipse_oracle_aggregate_3.aleo);
        return finalize_slash(feed_id, provider);
    }

    async function finalize_slash(
        public feed_id: field,
        public provider: address
    ) {
        // Zero out the stake & update counts
        let key: field = feed_id + (provider as field);
        let provider_stake: u128 = stakes.get(key);
        assert(provider_stake > 0u128);

        stakes.set(key, 0u128);

        let prev_total: u128 = total_staked.get_or_use(feed_id, 0u128);
        total_staked.set(feed_id, prev_total - provider_stake);

        let count: u32 = provider_count.get_or_use(feed_id, 0u32);
        assert(count > 0u32);
        provider_count.set(feed_id, count - 1u32);

        let last_idx: u32 = count - 1u32;
        let slot_last: field = feed_id + (last_idx as field);
        provider_list.set(
            slot_last,
            aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv // to be replaced by aleo zero address (couldn't find it anywhere...)
        );
    }

    // ====================================================================
    // 4. Add provider (manual list maintenance)
    // ====================================================================
    //
    // Ensures that a staker with sufficient stake is present in the
    // provider list.  If the list is full, the *smallest* staker is
    // replaced (to keep competition healthy).
    //
    async transition add_provider(
        public feed_id: field,
        public provider: address
    ) -> Future {
        return finalize_add_provider(feed_id, provider);
    }

    async function finalize_add_provider(
        public feed_id: field,
        public provider: address
    ) {
        let cfg: FeedConfig = eclipse_oracle_feed.aleo/feeds.get(feed_id);
        assert(!cfg.paused);

        // Provider must already have a positive stake
        let key_p: field = feed_id + (provider as field);
        let stake_p: u128 = stakes.get_or_use(key_p, 0u128);
        assert(stake_p > 0u128);

        // Reject duplicates
        let count: u32 = provider_count.get_or_use(feed_id, 0u32);
        for i: u32 in 0u32..MAX_PROVIDERS {
            if (i < count) {
                let k_i: field = feed_id + (i as field);
                let p: address = provider_list.get(k_i);
                assert(p != provider);
            }
        }

        // ------------------------------------------------------------
        // Case 1: list not full → append
        // ------------------------------------------------------------
        if (count < MAX_PROVIDERS) {
            let slot: field = feed_id + (count as field);
            provider_list.set(slot, provider);
            provider_count.set(feed_id, count + 1u32);
            return;
        }

        // ------------------------------------------------------------
        // Case 2: list full → find & replace the min-stake provider
        // ------------------------------------------------------------
        let key0: field = feed_id + (0u32 as field); let p0: address = provider_list.get(key0);
        let key1: field = feed_id + (1u32 as field); let p1: address = provider_list.get(key1);
        let key2: field = feed_id + (2u32 as field); let p2: address = provider_list.get(key2);
        let key3: field = feed_id + (3u32 as field); let p3: address = provider_list.get(key3);
        let key4: field = feed_id + (4u32 as field); let p4: address = provider_list.get(key4);
        let key5: field = feed_id + (5u32 as field); let p5: address = provider_list.get(key5);
        let key6: field = feed_id + (6u32 as field); let p6: address = provider_list.get(key6);
        let key7: field = feed_id + (7u32 as field); let p7: address = provider_list.get(key7);

        // Retrieve stakes of the eight incumbents
        let s0: u128 = stakes.get_or_use(feed_id + (p0 as field), 0u128);
        let s1: u128 = stakes.get_or_use(feed_id + (p1 as field), 0u128);
        let s2: u128 = stakes.get_or_use(feed_id + (p2 as field), 0u128);
        let s3: u128 = stakes.get_or_use(feed_id + (p3 as field), 0u128);
        let s4: u128 = stakes.get_or_use(feed_id + (p4 as field), 0u128);
        let s5: u128 = stakes.get_or_use(feed_id + (p5 as field), 0u128);
        let s6: u128 = stakes.get_or_use(feed_id + (p6 as field), 0u128);
        let s7: u128 = stakes.get_or_use(feed_id + (p7 as field), 0u128);

        // Pairwise tournament to find the minimum stake & its index
        let less01: bool = s1 < s0; let m01: u128 = less01 ? s1 : s0; let i01: u32 = less01 ? 1u32 : 0u32;
        let less23: bool = s3 < s2; let m23: u128 = less23 ? s3 : s2; let i23: u32 = less23 ? 3u32 : 2u32;
        let less0123: bool = m23 < m01; let m0123: u128 = less0123 ? m23 : m01; let i0123: u32 = less0123 ? i23 : i01;

        let less45: bool = s5 < s4; let m45: u128 = less45 ? s5 : s4; let i45: u32 = less45 ? 5u32 : 4u32;
        let less67: bool = s7 < s6; let m67: u128 = less67 ? s7 : s6; let i67: u32 = less67 ? 7u32 : 6u32;
        let less4567: bool = m67 < m45; let m4567: u128 = less4567 ? m67 : m45; let i4567: u32 = less4567 ? i67 : i45;

        let less_all: bool = m4567 < m0123;
        let min_stake: u128 = less_all ? m4567 : m0123;
        let idx_min:   u32  = less_all ? i4567 : i0123;

        // Only replace if newcomer > current minimum
        assert(stake_p > min_stake);

        let slot_old: field = feed_id + (idx_min as field);
        provider_list.set(slot_old, provider);
    }
}
