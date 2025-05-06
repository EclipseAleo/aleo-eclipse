program eclipse_oracle_feed.aleo {
    struct FeedConfig {
        creator: address,
        min_stake: u64,
        slashing_threshold: u64,
        aggregation_window: u32,
        challenge_window: u32,
        paused: bool
    }

    mapping feeds: field => FeedConfig;

    // --------------------------------------------------------
    // 1. Création d’un feed avec challenge_window
    // --------------------------------------------------------
    async transition create_feed(
        public feed_id: field,
        public min_stake: u64,
        public slashing_threshold: u64,
        public aggregation_window: u32,
        public challenge_window: u32,
        public caller: address
    ) -> Future {
        return finalize_create_feed(
            feed_id,
            min_stake,
            slashing_threshold,
            aggregation_window,
            challenge_window,
            caller
        );
    }
    async function finalize_create_feed(
        public feed_id: field,
        public min_stake: u64,
        public slashing_threshold: u64,
        public aggregation_window: u32,
        public challenge_window: u32,
        public caller: address
    ) {
        assert(!feeds.contains(feed_id));
        let cfg: FeedConfig = FeedConfig{
            creator: caller,
            min_stake: min_stake,
            slashing_threshold: slashing_threshold,
            aggregation_window: aggregation_window,
            challenge_window: challenge_window,
            paused: false
        };
        feeds.set(feed_id,cfg);
    }

    // --------------------------------------------------------
    // 2. Pause du feed
    // --------------------------------------------------------
    async transition pause_feed(
        public feed_id: field,
        public caller: address
    ) -> Future {
        return finalize_pause_feed(feed_id,caller);
    }
    async function finalize_pause_feed(
        public feed_id: field,
        public caller: address
    ) {
        let cfg: FeedConfig = feeds.get(feed_id);
        assert(caller == cfg.creator);
        assert(!cfg.paused);
        let updated: FeedConfig = FeedConfig{
            creator: cfg.creator,
            min_stake: cfg.min_stake,
            slashing_threshold: cfg.slashing_threshold,
            aggregation_window: cfg.aggregation_window,
            challenge_window: cfg.challenge_window,
            paused: true
        };
        feeds.set(feed_id,updated);
    }

    // --------------------------------------------------------
    // 3. Reprise du feed
    // --------------------------------------------------------
    async transition resume_feed(
        public feed_id: field,
        public caller: address
    ) -> Future {
        return finalize_resume_feed(feed_id,caller);
    }
    async function finalize_resume_feed(
        public feed_id: field,
        public caller: address
    ) {
        let cfg: FeedConfig = feeds.get(feed_id);
        assert(caller == cfg.creator);
        assert(cfg.paused);
        let updated: FeedConfig = FeedConfig{
            creator: cfg.creator,
            min_stake: cfg.min_stake,
            slashing_threshold: cfg.slashing_threshold,
            aggregation_window: cfg.aggregation_window,
            challenge_window: cfg.challenge_window,
            paused: false
        };
        feeds.set(feed_id,updated);
    }
}
