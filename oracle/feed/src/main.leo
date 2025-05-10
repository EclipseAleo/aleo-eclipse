/// Eclipse Oracle – Feed Registry
///
/// Author : **Florent Gaujal** <https://github.com/floflo777>
/// Date   : 2025-05-10
///
/// ### Purpose
/// Central registry that **creates** price feeds and lets the creator
/// *pause* / *resume* them for emergency situations. Each feed stores its
/// own economic parameters that are read by the Staking, Submit and
/// Aggregate contracts.
///
/// ### Storage
/// | Mapping | Key | Value | Description |
/// |---------|-----|-------|-------------|
/// | `feeds` | `feed_id` | `FeedConfig` | Immutable economic params + `paused` flag |
///
/// ### Invariants
/// - A `feed_id` is unique; creation fails if already present.
/// - Only the `creator` of a feed can pause or resume it.
///
program eclipse_oracle_feed.aleo {
    /// Immutable (except `paused`) configuration of a single feed.
    struct FeedConfig {
        creator: address,          /// Account that created the feed
        min_stake: u64,            /// Minimum stake required per provider
        slashing_threshold: u64,   /// Max price deviation tolerated
        aggregation_window: u32,   /// Blocks between two valid submissions
        challenge_window: u32,     /// Time left to slash an aggregator
        paused: bool               /// Emergency stop flag
    }

    mapping feeds: field => FeedConfig;   /// Registry of all feeds

    // =====================================================================
    // 1. Create a new feed
    // =====================================================================

    /// Registers a **new** feed with its economic parameters.
    ///
    /// **Pre‑conditions**
    /// - `feed_id` is **not** already in `feeds`.
    ///
    /// **Effects**
    /// - Stores `FeedConfig` with `paused = false`.
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

    /// Continuation of `create_feed` after async boundary (no external call).
    async function finalize_create_feed(
        public feed_id: field,
        public min_stake: u64,
        public slashing_threshold: u64,
        public aggregation_window: u32,
        public challenge_window: u32,
        public caller: address
    ) {
        assert(!feeds.contains(feed_id));   // enforce uniqueness
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

    // =====================================================================
    // 2. Pause a feed
    // =====================================================================

    /// Temporarily stops submissions & staking for a feed.
    ///
    /// **Pre‑conditions**
    /// - `caller` is the feed `creator`.
    /// - Feed is **not** already paused.
    ///
    /// **Effects**
    /// - Sets `paused = true` in `feeds[feed_id]`.
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

    // =====================================================================
    // 3. Resume a feed
    // =====================================================================

    /// Lifts the pause flag so providers can operate again.
    ///
    /// **Pre‑conditions**
    /// - `caller` is the feed `creator`.
    /// - Feed **is** currently paused.
    ///
    /// **Effects**
    /// - Sets `paused = false`.
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
