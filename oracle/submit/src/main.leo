////////////////////////////////////////////////////////////////////////////////
// Eclipse Oracle – Submit v2
//
// Author : **Florent Gaujal** <https://github.com/floflo777>
// Date   : 2025-05-10
//
// ### Purpose
// Enables **data providers** to push *individual* price observations for a
// specific feed.  Each valid submission:
// - must respect the `aggregation_window` (per-provider cooldown),
// - earns a small fixed reward (`SUBMIT_REWARD`, minted on demand),
// - is stored temporarily until the next aggregation cycle.
//
// ### Storage
// | Mapping                  | Key                   | Value | Description                       |
// |--------------------------|-----------------------|-------|-----------------------------------|
// | `temp_price`             | `feed_id‖provider`    | u128  | Last submitted price              |
// | `last_ts`                | `feed_id‖provider`    | u64   | Block timestamp of last submit    |
// | `provider_pending_reward`| `provider`            | u16   | Accrued rewards yet to be claimed |
//
// ### Invariants
// - A provider must have a positive stake in `Staking` to submit.
// - Consecutive submissions from the *same* provider must be separated by
//   ≤ `aggregation_window` blocks. Possible to submit multiple prices before then.
// - `reward` tokens are minted only when claimed (`claim_pending_reward`).
//
import eclipse_oracle_feed.aleo;
import eclipse_oracle_staking_2.aleo;
import token_registry.aleo;

program eclipse_oracle_submit_2.aleo {

    // Feed config
    struct FeedConfig {
        creator: address,
        min_stake: u64,
        slashing_threshold: u64,
        aggregation_window: u32,
        challenge_window: u32,
        paused: bool
    }

    const SUBMIT_REWARD: u16  = 1u16;                    // reward per submit
    const TOKEN_ID: field = 123456789101field;       // reward token

    // --------------------------------------------------------------------
    //  Persistent storage
    // --------------------------------------------------------------------
    mapping temp_price: field => u128;    // last submitted price
    mapping last_ts: field => u64;     // block timestamp
    mapping provider_pending_reward: address => u16;    // unclaimed rewards

    // ====================================================================
    // 1. Submit a price
    // ====================================================================
    //
    // Stores the submitted price & credits reward.
    //
    async transition submit_price(
        public feed_id: field,
        public price: u128,
        public caller: address
    ) -> Future {
        return finalize_submit(feed_id, price, caller);
    }

    async function finalize_submit(
        public feed_id: field,
        public price: u128,
        public caller: address
    ) {
        let cfg: FeedConfig = eclipse_oracle_feed.aleo/feeds.get(feed_id);
        assert(!cfg.paused);

        // Provider must be staked
        let key: field  = feed_id + (caller as field);
        let stake: u128 = eclipse_oracle_staking_2.aleo/stakes.get_or_use(key, 0u128);
        assert(stake > 0u128);

        // Enforce per-provider cooldown
        let now:  u64 = block.height as u64;
        let prev: u64 = last_ts.get_or_use(key, 0u64);
        assert(now > prev); 
        if (prev != 0u64) {
            let delta: u64 = now - prev;
            assert(delta <= (cfg.aggregation_window as u64));
        }

        assert(price > 0u128);

        // Persist state
        last_ts.set(key, now);
        temp_price.set(key, price);

        // Credit reward
        let pending: u16 = provider_pending_reward.get_or_use(caller, 0u16);
        provider_pending_reward.set(caller, pending + SUBMIT_REWARD);
    }

    // ====================================================================
    // 2. Claim accrued rewards
    // ====================================================================
    //
    // Mints the exact pending amount to the provider and resets counter.
    //
    async transition claim_pending_reward(
        public caller: address,
        public reward: u16
    ) -> Future {
        assert(caller == self.caller);

        let f_reward: Future = token_registry.aleo/mint_public(
            TOKEN_ID,
            caller,
            reward as u128,
            0u32
        );
        return finalize_claim_pending_reward(f_reward, caller, reward);
    }

    async function finalize_claim_pending_reward(
        f_reward: Future,
        public caller: address,
        public reward: u16
    ) {
        let pending: u16 = provider_pending_reward.get_or_use(caller, 0u16);
        assert(pending > 0u16);
        assert(pending == reward);           
        provider_pending_reward.set(caller, 0u16);
        f_reward.await();                   
    }
}
