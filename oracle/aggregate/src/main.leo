////////////////////////////////////////////////////////////////////////////////
// Eclipse Oracle – Aggregate v2
//
// Author : **Florent Gaujal** <https://github.com/floflo777>
// Date   : 2025-05-10
//
// ### Purpose
// Produces a **robust, slashing-backed median** from provider submissions.
// Workflow per feed:
// 1. *Propose*   — any staked provider suggests a median price.
// 2. *Challenge* — within `challenge_window`, anyone may:
//      • *slash_aggregator* if median is inconsistent (≤ N good providers),
//      • *slash_provider*   to punish outliers > `slashing_threshold`.
// 3. *Finalize*   — after the window, if not slashed, proposer mints reward.
//
// Slashing burns the entire stake of the faulty party and compensates the
// first challenger.
//
// ### Storage
// | Mapping            | Key          | Value    | Description                          |
// |--------------------|--------------|----------|--------------------------------------|
// | `latest_price`     | `feed_id`    | u128     | Last accepted median                 |
// | `proposal_median`  | `feed_id`    | u128     | Median currently under challenge     |
// | `proposal_proposer`| `feed_id`    | address  | Who proposed the median              |
// | `proposal_block`   | `feed_id`    | u32      | Block of proposal                    |
// | `proposal_slashed` | `feed_id`    | bool     | Flag once proposer is slashed        |
// | `aggregate_done`   | `feed_id`    | bool     | Flag once median is finalized        |
// | `slasher`          | `feed_id`    | address  | Challenger entitled to slash reward  |
// | `slasher_reward`   | `feed_id`    | u128     | Reward pending for the slasher       |
// | `last_propose_block`| `feed_id`   | u32      | Cooldown to limit propose frequency  |
//
// ### Invariants
// - Only a provider with ≥ `min_stake` may propose or finalize.
// - A proposal is unique per feed until `aggregate_done` flips true.
// - Slashing is allowed **once** per proposal.
// - `latest_price` is updated only by a validated (non-slashed) proposal.
//
import eclipse_oracle_feed.aleo;
import eclipse_oracle_submit_2.aleo;
import eclipse_oracle_staking_2.aleo;
import token_registry.aleo;

program eclipse_oracle_aggregate_2.aleo {

    // --------------------------------------------------------------------
    //  Constants
    // --------------------------------------------------------------------
    const MAX_PROVIDERS:     u32   = 8u32;
    const MIN_PROVIDERS:     u32   = 6u32;            // quorum for validation
    const aggregator_reward: u128 = 1u128;            // mint for proposer
    const token_id:          field = 123456789101field;

    // Feed config mirror
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
    mapping latest_price:      field => u128;
    mapping proposal_median:   field => u128;
    mapping proposal_proposer: field => address;
    mapping proposal_block:    field => u32;
    mapping proposal_slashed:  field => bool;
    mapping aggregate_done:    field => bool;
    mapping slasher:           field => address;
    mapping slasher_reward:    field => u128;
    mapping last_propose_block:field => u32;

    // ====================================================================
    // 1. Propose a median
    // ====================================================================
    //
    async transition propose(
        public feed_id: field,
        public median:  u128,
        public caller:  address
    ) -> Future {
        return finalize_propose(feed_id, median, caller);
    }

    async function finalize_propose(
        public feed_id: field,
        public median:  u128,
        public caller:  address
    ) {
        // Require sufficient active providers
        let count: u32 = eclipse_oracle_staking_2.aleo/provider_count.get_or_use(feed_id, 0u32);
        assert(count >= MIN_PROVIDERS);

        let cfg: FeedConfig = eclipse_oracle_feed.aleo/feeds.get(feed_id);
        assert(!cfg.paused);

        // Proposer must have ≥ min_stake
        let key: field = feed_id + (caller as field);
        let stake: u128 = eclipse_oracle_staking_2.aleo/stakes.get_or_use(key, 0u128);
        assert(stake >= (cfg.min_stake as u128));

        // Enforce cooldown between proposals
        let prev_blk: u32 = last_propose_block.get_or_use(feed_id, 0u32);
        let now_u64: u64 = block.height as u64;
        assert(now_u64 >= (prev_blk as u64) + (cfg.aggregation_window as u64));
        last_propose_block.set(feed_id, block.height);

        assert(median > 0u128);

        // Record proposal (overwrites any previous, but guarded by cooldown)
        let h: u32 = block.height;
        proposal_median.set(feed_id, median);
        proposal_proposer.set(feed_id, caller);
        proposal_block.set(feed_id, h);
        proposal_slashed.set(feed_id, false);
        aggregate_done.set(feed_id, false);
    }

    // ====================================================================
    // 2. Slash an *invalid* aggregator
    // ====================================================================
    //
    // If fewer than `MIN_PROVIDERS` good submissions fall inside
    // `slashing_threshold` distance from the proposed median, the proposer
    // is slashed and the challenger is rewarded (`min_stake`).
    //
    async transition slash_aggregator(
        public feed_id: field,
        public proposer: address
    ) -> Future {
        let f_slash: Future = eclipse_oracle_staking_2.aleo/slash(feed_id, proposer);
        return finalize_slash(f_slash, feed_id, proposer, self.caller);
    }

    async function finalize_slash(
        f_slash: Future,
        public feed_id: field,
        public proposer: address,
        public slasher_add: address
    ) {
        let recorded: address = proposal_proposer.get(feed_id);
        assert(proposer == recorded);           // correct target

        let cfg: FeedConfig = eclipse_oracle_feed.aleo/feeds.get(feed_id);
        // Slash only within challenge_window
        let prop_blk: u32 = proposal_block.get(feed_id);
        assert(block.height <= prop_blk + cfg.challenge_window);

        assert(!proposal_slashed.get_or_use(feed_id, false)); // single shot

        // ------------------------------------------------------------
        // Count how many provider prices lie within threshold distance
        // from the proposed median.
        // ------------------------------------------------------------
        let median: u128 = proposal_median.get(feed_id);
        let threshold: u128 = cfg.slashing_threshold as u128;
        let count: u32 = eclipse_oracle_staking_2.aleo/provider_count.get_or_use(feed_id, 0u32);

        // Enumerate up to 8 providers (unrolled for gas determinism)
        let slot0: field = feed_id + (0u32 as field); let p0: address = eclipse_oracle_staking_2.aleo/provider_list.get(slot0);
        let price0: u128 = eclipse_oracle_submit_2.aleo/temp_price.get_or_use(feed_id + (p0 as field), 0u128);
        let diff0: u128 = (price0 >= median) ? (price0 - median) : (median - price0);
        let cond0: u32 = (0u32 < count && diff0 <= threshold) ? 1u32 : 0u32;

        let slot1: field = feed_id + (1u32 as field); let p1: address = eclipse_oracle_staking_2.aleo/provider_list.get(slot1);
        let price1: u128 = eclipse_oracle_submit_2.aleo/temp_price.get_or_use(feed_id + (p1 as field), 0u128);
        let diff1: u128 = (price1 >= median) ? (price1 - median) : (median - price1);
        let cond1: u32 = (1u32 < count && diff1 <= threshold) ? 1u32 : 0u32;

        let slot2: field = feed_id + (2u32 as field); let p2: address = eclipse_oracle_staking_2.aleo/provider_list.get(slot2);
        let price2: u128 = eclipse_oracle_submit_2.aleo/temp_price.get_or_use(feed_id + (p2 as field), 0u128);
        let diff2: u128 = (price2 >= median) ? (price2 - median) : (median - price2);
        let cond2: u32 = (2u32 < count && diff2 <= threshold) ? 1u32 : 0u32;

        let slot3: field = feed_id + (3u32 as field); let p3: address = eclipse_oracle_staking_2.aleo/provider_list.get(slot3);
        let price3: u128 = eclipse_oracle_submit_2.aleo/temp_price.get_or_use(feed_id + (p3 as field), 0u128);
        let diff3: u128 = (price3 >= median) ? (price3 - median) : (median - price3);
        let cond3: u32 = (3u32 < count && diff3 <= threshold) ? 1u32 : 0u32;

        let slot4: field = feed_id + (4u32 as field); let p4: address = eclipse_oracle_staking_2.aleo/provider_list.get(slot4);
        let price4: u128 = eclipse_oracle_submit_2.aleo/temp_price.get_or_use(feed_id + (p4 as field), 0u128);
        let diff4: u128 = (price4 >= median) ? (price4 - median) : (median - price4);
        let cond4: u32 = (4u32 < count && diff4 <= threshold) ? 1u32 : 0u32;

        let slot5: field = feed_id + (5u32 as field); let p5: address = eclipse_oracle_staking_2.aleo/provider_list.get(slot5);
        let price5: u128 = eclipse_oracle_submit_2.aleo/temp_price.get_or_use(feed_id + (p5 as field), 0u128);
        let diff5: u128 = (price5 >= median) ? (price5 - median) : (median - price5);
        let cond5: u32 = (5u32 < count && diff5 <= threshold) ? 1u32 : 0u32;

        let slot6: field = feed_id + (6u32 as field); let p6: address = eclipse_oracle_staking_2.aleo/provider_list.get(slot6);
        let price6: u128 = eclipse_oracle_submit_2.aleo/temp_price.get_or_use(feed_id + (p6 as field), 0u128);
        let diff6: u128 = (price6 >= median) ? (price6 - median) : (median - price6);
        let cond6: u32 = (6u32 < count && diff6 <= threshold) ? 1u32 : 0u32;

        let slot7: field = feed_id + (7u32 as field); let p7: address = eclipse_oracle_staking_2.aleo/provider_list.get(slot7);
        let price7: u128 = eclipse_oracle_submit_2.aleo/temp_price.get_or_use(feed_id + (p7 as field), 0u128);
        let diff7: u128 = (price7 >= median) ? (price7 - median) : (median - price7);
        let cond7: u32 = (7u32 < count && diff7 <= threshold) ? 1u32 : 0u32;

        let valid_sum: u32 =
            cond0 + cond1 + cond2 + cond3 +
            cond4 + cond5 + cond6 + cond7;

        // Slash if quorum of “good” providers not met
        if valid_sum < MIN_PROVIDERS {
            f_slash.await();                                  // burns stake
            proposal_slashed.set(feed_id, true);
            slasher.set(feed_id, slasher_add);                // record challenger
            slasher_reward.set(feed_id, cfg.min_stake as u128);
            return;
        }

        // Otherwise, aggregation is valid → challenger loses its tx fees
        assert(false);   // revert (cannot slash a good proposal)
    }

    // ====================================================================
    // 3. Finalize (after challenge window)
    // ====================================================================
    async transition finalize_aggregate(
        public feed_id: field,
        public caller:  address
    ) -> Future {
        let f_reward: Future = token_registry.aleo/mint_public(
            token_id,
            caller,
            aggregator_reward,
            0u32
        );
        return finalize_aggregate_internal(f_reward, feed_id, caller);
    }

    async function finalize_aggregate_internal(
        f_reward: Future,
        public feed_id: field,
        public caller:  address
    ) {
        assert(!aggregate_done.get_or_use(feed_id, false));

        let cfg: FeedConfig = eclipse_oracle_feed.aleo/feeds.get(feed_id);

        // Ensure challenge window passed
        let prop_blk: u32 = proposal_block.get(feed_id);
        assert(block.height > prop_blk + cfg.challenge_window);

        // Proposer must not have been slashed
        assert(!proposal_slashed.get_or_use(feed_id, false));

        // Finalizer must have min_stake (covers both proposer & relayers)
        let key: field = feed_id + (caller as field);
        let stake: u128 = eclipse_oracle_staking_2.aleo/stakes.get_or_use(key, 0u128);
        assert(stake >= (cfg.min_stake as u128));

        // Commit median
        let median: u128 = proposal_median.get(feed_id);
        latest_price.set(feed_id, median);
        aggregate_done.set(feed_id, true);

        f_reward.await();   // mint aggregator reward
    }

    // ====================================================================
    // 4. Claim slasher reward
    // ====================================================================
    async transition claim_slash(
        public feed_id:      field,
        public slasher_input:address,
        public amount_input: u128
    ) -> Future {
        let f: Future = token_registry.aleo/mint_public(
            token_id,
            slasher_input,
            amount_input,
            0u32
        );
        return finalize_claim_slash(f, feed_id, slasher_input, amount_input);
    }

    async function finalize_claim_slash(
        f: Future,
        public feed_id:      field,
        public slasher_input:address,
        public amount_input: u128
    ) {
        let stored_slash_addr: address = slasher.get(feed_id);
        assert(slasher_input == stored_slash_addr);

        let stored_amount: u128 = slasher_reward.get(feed_id);
        assert(amount_input == stored_amount);

        f.await();                               // mint reward
        // Reset state
        slasher_reward.set(feed_id, 0u128);
        slasher.set(feed_id,
            aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv);
    }

    // ====================================================================
    // 5. Slash an *outlier* provider
    // ====================================================================
    async transition slash_provider(
        public feed_id: field,
        public provider: address
    ) -> Future {
        let f_slash: Future =
            eclipse_oracle_staking_2.aleo/slash(feed_id, provider);
        return finalize_slash_provider(f_slash, feed_id, provider);
    }

    async function finalize_slash_provider(
        f_slash: Future,
        public feed_id: field,
        public provider: address
    ) {
        let cfg: FeedConfig = eclipse_oracle_feed.aleo/feeds.get(feed_id);
        assert(!cfg.paused);

        // Compare provider’s last price vs current proposal median
        let median: u128 = proposal_median.get(feed_id);
        let price:  u128 = eclipse_oracle_submit_2.aleo/temp_price.get_or_use(
            feed_id + (provider as field), 0u128);
        let diff:   u128 = (price >= median) ? (price - median) : (median - price);
        assert(diff > (cfg.slashing_threshold as u128));  // only major outliers

        f_slash.await();      // burn stake
    }
}
