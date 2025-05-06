import flo_oracle_feed.aleo;
import flo_oracle_staking.aleo;

program flo_oracle_submit.aleo {
    struct FeedConfig {
        creator:              address,
        min_stake:            u128,
        slashing_threshold:   u128,
        aggregation_window:   u64,
        paused:               bool
    }

    mapping temp_price: field => u128;
    mapping last_ts:     field => u64;

    async transition submit_price(
        public feed_id: field,
        public price:   u128,
        public ts:      u64,
        public caller:  address
    ) -> Future {
        return finalize_submit(feed_id, price, ts, caller);
    }

    async function finalize_submit(
        public feed_id: field,
        public price:   u128,
        public ts:      u64,
        public caller:  address
    ) {
        let cfg: FeedConfig = Mapping::get(flo_oracle_feed.aleo/feeds, feed_id);
        assert(!cfg.paused);

        let key:   field = feed_id + (caller as field);
        let stake: u128 = Mapping::get_or_use(flo_oracle_staking.aleo/stakes, key, 0u128);
        assert(stake > 0u128);

        let prev_ts: u64 = Mapping::get_or_use(last_ts, key, 0u64);
        assert(ts > prev_ts);
        let delta: u64 = ts - prev_ts;
        assert(delta <= cfg.aggregation_window);

        assert(price > 0u128);
        Mapping::set(last_ts,   key, ts);
        Mapping::set(temp_price, key, price);
    }
}