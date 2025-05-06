import eclipse_oracle_feed.aleo;
import eclipse_oracle_staking.aleo;
import token_registry.aleo;

program eclipse_oracle_submit.aleo {
    struct FeedConfig {
        creator: address,
        min_stake: u64,
        slashing_threshold: u64,
        aggregation_window: u32,
        challenge_window: u32,
        paused: bool
    }

    const submit_reward: u16 = 1u16;
    const token_id: field = 12345678910field;

    mapping temp_price: field => u128;
    mapping last_ts: field => u64;
    mapping provider_pending_reward: address => u16;

    // --------------------------------------------------------
    // 1. Soumission d'un prix
    // --------------------------------------------------------
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
        public caller:  address
    ) {
        let cfg: FeedConfig = eclipse_oracle_feed.aleo/feeds.get(feed_id);
        assert(!cfg.paused);

        let key: field = feed_id + (caller as field);
        let stake: u128  = eclipse_oracle_staking.aleo/stakes.get_or_use(key, 0u128);
        assert(stake > 0u128);

        let height: u32 = block.height;
        let now: u64 = height as u64;
        let prev_ts: u64 = last_ts.get_or_use(key, 0u64);
        assert(now > prev_ts);
        let delta: u64 = now - prev_ts;
        assert(delta <= (cfg.aggregation_window as u64));

        assert(price > 0u128);

        last_ts.set(key, now);
        temp_price.set(key, price);

        let pending: u16 = provider_pending_reward.get_or_use(caller, 0u16);
        provider_pending_reward.set(caller, pending + submit_reward);
    }


    // --------------------------------------------------------
    // 2. Réclamation de la récompense
    // --------------------------------------------------------
    async transition claim_pending_reward(
        public caller: address,
        public reward: u16
    ) -> Future {
        assert(caller == self.caller);
        let f_reward: Future = token_registry.aleo/mint_public(
            token_id,
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
