import eclipse_oracle_feed.aleo;
import token_registry.aleo;

program eclipse_oracle_staking_2.aleo {
    const MAX_PROVIDERS: u32 = 8u32;
    const token_id: field = 123456789101field;

    struct FeedConfig {
        creator: address,
        min_stake: u64,
        slashing_threshold: u64,
        aggregation_window: u32,
        challenge_window: u32,
        paused: bool
    }

    mapping total_staked: field => u128;
    mapping stakes: field => u128;
    mapping provider_count: field => u32;
    mapping provider_list: field => address;

    // --------------------------------------------------------
    // 1. Stake
    // --------------------------------------------------------
    async transition stake(
        public feed_id: field,
        public amount: u128,
        public caller: address
    ) -> Future {
        let (rec, f): (token_registry.aleo/Token, Future) =
            token_registry.aleo/transfer_public_to_private(
                token_id,
                caller,
                amount,
                false
            );
        return finalize_stake(f, feed_id, amount, caller);
    }
    async function finalize_stake(
        f: Future,
        public feed_id: field,
        public amount: u128,
        public caller: address
    ) {
        f.await();
        
        let cfg: FeedConfig = eclipse_oracle_feed.aleo/feeds.get(feed_id);
        assert(!cfg.paused);
        assert(amount > 0u128);

        let key: field = feed_id + (caller as field);
        let prev: u128 = stakes.get_or_use(key, 0u128);
        if (prev == 0u128) {
            assert(amount >= cfg.min_stake as u128);
        }

        let new_stake: u128 = prev + amount;
        stakes.set(key, new_stake);

        let prev_total: u128 = total_staked.get_or_use(feed_id, 0u128);
        total_staked.set(feed_id, prev_total + amount);

        let count: u32 = provider_count.get_or_use(feed_id, 0u32);
        if (prev == 0u128 && count < MAX_PROVIDERS) {
            for i: u32 in 0u32..MAX_PROVIDERS {
                if (i < count) {
                    let key_i: field = feed_id + (i as field);
                    let p: address = provider_list.get(key_i);
                    assert(p != caller);
                }
            }
            let new_key: field = feed_id + (count as field);
            provider_list.set(new_key, caller);
            provider_count.set(feed_id, count + 1u32);
        }
    }

    // --------------------------------------------------------
    // 2. Withdraw
    // --------------------------------------------------------
    async transition withdraw(
        public feed_id: field,
        public amount: u128,
        public caller: address
    ) -> Future {
        let f: Future = token_registry.aleo/transfer_public(
            token_id,
            caller,
            amount
        );
        return finalize_withdraw(f, feed_id, amount, caller);
    }
    async function finalize_withdraw(
        f: Future,
        public feed_id: field,
        public amount: u128,
        public caller: address
    ) {
        f.await();
        let cfg: FeedConfig = eclipse_oracle_feed.aleo/feeds.get(feed_id);
        assert(!cfg.paused);
        assert(amount > 0u128);

        let key: field = feed_id + (caller as field);
        let prev: u128 = stakes.get(key);
        assert(prev >= amount);
        let new_stake: u128 = prev - amount;
        assert(new_stake == 0u128 || new_stake >= cfg.min_stake as u128);

        stakes.set(key, new_stake);

        let prev_total: u128 = total_staked.get_or_use(feed_id, 0u128);
        total_staked.set(feed_id, prev_total - amount);
    }

    // --------------------------------------------------------
    // 3. Slash
    // --------------------------------------------------------
    async transition slash(
        public feed_id: field,
        public provider: address
    ) -> Future {
        assert(self.caller == eclipse_oracle_aggregate_2.aleo);
        return finalize_slash(feed_id, provider);
    }
    async function finalize_slash(
        public feed_id: field,
        public provider: address
    ) {
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
            aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv
        );
    }

    // --------------------------------------------------------
    // 4. Add provider
    // --------------------------------------------------------
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

        let key_p: field = feed_id + (provider as field);
        let stake_p: u128 = stakes.get_or_use(key_p, 0u128);
        assert(stake_p > 0u128);

        let count: u32 = provider_count.get_or_use(feed_id, 0u32);
        for i: u32 in 0u32..MAX_PROVIDERS {
            if (i < count) {
                let k_i: field = feed_id + (i as field);
                let p: address = provider_list.get(k_i);
                assert(p != provider);
            }
        }

        if (count < MAX_PROVIDERS) {
            let slot: field = feed_id + (count as field);
            provider_list.set(slot, provider);
            provider_count.set(feed_id, count + 1u32);
            return;
        }

        let key0: field = feed_id + (0u32 as field);
        let p0: address = provider_list.get(key0);
        let key1: field = feed_id + (1u32 as field);
        let p1: address = provider_list.get(key1);
        let key2: field = feed_id + (2u32 as field);
        let p2: address = provider_list.get(key2);
        let key3: field = feed_id + (3u32 as field);
        let p3: address = provider_list.get(key3);
        let key4: field = feed_id + (4u32 as field);
        let p4: address = provider_list.get(key4);
        let key5: field = feed_id + (5u32 as field);
        let p5: address = provider_list.get(key5);
        let key6: field = feed_id + (6u32 as field);
        let p6: address = provider_list.get(key6);
        let key7: field = feed_id + (7u32 as field);
        let p7: address = provider_list.get(key7);

        let s0: u128 = stakes.get_or_use(feed_id + (p0 as field), 0u128);
        let s1: u128 = stakes.get_or_use(feed_id + (p1 as field), 0u128);
        let s2: u128 = stakes.get_or_use(feed_id + (p2 as field), 0u128);
        let s3: u128 = stakes.get_or_use(feed_id + (p3 as field), 0u128);
        let s4: u128 = stakes.get_or_use(feed_id + (p4 as field), 0u128);
        let s5: u128 = stakes.get_or_use(feed_id + (p5 as field), 0u128);
        let s6: u128 = stakes.get_or_use(feed_id + (p6 as field), 0u128);
        let s7: u128 = stakes.get_or_use(feed_id + (p7 as field), 0u128);

        let less01: bool = s1 < s0;
        let m01: u128 = less01 ? s1 : s0;
        let i01: u32 = less01 ? 1u32 : 0u32;

        let less23: bool = s3 < s2;
        let m23: u128 = less23 ? s3 : s2;
        let i23: u32 = less23 ? 3u32 : 2u32;

        let less0123: bool = m23 < m01;
        let m0123: u128 = less0123 ? m23 : m01;
        let i0123: u32 = less0123 ? i23 : i01;

        let less45: bool = s5 < s4;
        let m45: u128 = less45 ? s5 : s4;
        let i45: u32 = less45 ? 5u32 : 4u32;

        let less67: bool = s7 < s6;
        let m67: u128 = less67 ? s7 : s6;
        let i67: u32 = less67 ? 7u32 : 6u32;

        let less4567: bool = m67 < m45;
        let m4567: u128 = less4567 ? m67 : m45;
        let i4567: u32 = less4567 ? i67 : i45;

        let less_all: bool = m4567 < m0123;
        let min_stake: u128 = less_all ? m4567 : m0123;
        let idx_min: u32 = less_all ? i4567 : i0123;

        assert(stake_p > min_stake);

        let slot_old: field = feed_id + (idx_min as field);
        provider_list.set(slot_old, provider);
    }
}

