program feed_tests.aleo {
    import feed.aleo;

    // A simple helper test account
    // (replace with your actual testnet key if needed)
    let alice: address = aleo1hz4zt6awd6ts9zn8ppkwwvjwrg04ax48krd0fgnnzu6ezg9qxst3v26j;

    @test()
    function test_create_and_read_feed() {
        // 1) Arrange: some sample parameters
        let feed_id:            field   = 1field;
        let min_stake:          u128    = 100u128;
        let slashing_threshold: u128    =  10u128;
        let aggregation_window: u64     =  60u64;
        let caller:             address = alice;

        // 2) Act: call create_feed
        call feed.aleo/create_feed feed_id min_stake slashing_threshold aggregation_window caller into fut;
        fut.await();

        // 3) Assert: we can read the stored config
        let cfg: feed.aleo/FeedConfig = Mapping::get(feed.aleo/feeds, feed_id);
        assert(cfg.creator            == caller);
        assert(cfg.min_stake          == min_stake);
        assert(cfg.slashing_threshold == slashing_threshold);
        assert(cfg.aggregation_window == aggregation_window);
        assert(cfg.paused             == false);
    }

    @test()
    function test_cannot_create_duplicate() {
        // Arrange
        let feed_id:            field   = 2field;
        let min_stake:          u128    = 50u128;
        let slashing_threshold: u128    = 5u128;
        let aggregation_window: u64     = 30u64;
        let caller:             address = alice;

        // First creation succeeds
        call feed.aleo/create_feed feed_id min_stake slashing_threshold aggregation_window caller into fut1;
        fut1.await();

        // Second creation should fail (assert(!contains))
        // the test harness will catch any assertion as a failure
        call feed.aleo/create_feed feed_id min_stake slashing_threshold aggregation_window caller into fut2;
        // If this next line does *not* panic, the test fails:
        fut2.await();
    }
}
