program flo_oracle_feed.aleo {
    struct FeedConfig {
        creator:            address,
        min_stake:          u128,
        slashing_threshold: u128,
        aggregation_window: u64,
        paused:             bool
    }

    mapping feeds: field => FeedConfig;

    async transition create_feed(
        public feed_id:            field,
        public min_stake:          u128,
        public slashing_threshold: u128,
        public aggregation_window: u64,
        public caller:             address
    ) -> Future {
        return finalize_create_feed(
            feed_id,
            min_stake,
            slashing_threshold,
            aggregation_window,
            caller
        );
    }
    async function finalize_create_feed(
        public feed_id:            field,
        public min_stake:          u128,
        public slashing_threshold: u128,
        public aggregation_window: u64,
        public caller:             address
    ) {
        assert(!Mapping::contains(feeds, feed_id));
        let cfg: FeedConfig = FeedConfig {
            creator:            caller,
            min_stake,
            slashing_threshold,
            aggregation_window,
            paused:             false
        };
        Mapping::set(feeds, feed_id, cfg);
    }

    async transition pause_feed(
        public feed_id: field,
        public caller:  address
    ) -> Future {
        return finalize_pause_feed(feed_id, caller);
    }
    async function finalize_pause_feed(
        public feed_id: field,
        public caller:  address
    ) {
        let cfg: FeedConfig = Mapping::get(feeds, feed_id);
        assert(caller == cfg.creator);
        assert(!cfg.paused);
        let updated: FeedConfig = FeedConfig {
            creator:            cfg.creator,
            min_stake:          cfg.min_stake,
            slashing_threshold: cfg.slashing_threshold,
            aggregation_window: cfg.aggregation_window,
            paused:             true
        };
        Mapping::set(feeds, feed_id, updated);
    }

    async transition resume_feed(
        public feed_id: field,
        public caller:  address
    ) -> Future {
        return finalize_resume_feed(feed_id, caller);
    }
    async function finalize_resume_feed(
        public feed_id: field,
        public caller:  address
    ) {
        let cfg: FeedConfig = Mapping::get(feeds, feed_id);
        assert(caller == cfg.creator);
        assert(cfg.paused);
        let updated: FeedConfig = FeedConfig {
            creator:            cfg.creator,
            min_stake:          cfg.min_stake,
            slashing_threshold: cfg.slashing_threshold,
            aggregation_window: cfg.aggregation_window,
            paused:             false
        };
        Mapping::set(feeds, feed_id, updated);
    }
}