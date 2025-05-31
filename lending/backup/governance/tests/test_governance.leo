// The 'test_governance' test program.
import governance.aleo;
program test_governance.aleo {
    @test
    script test_it() {
        let result: u32 = governance.aleo/main(1u32, 2u32);
        assert_eq(result, 3u32);
    }

    @test
    @should_fail
    transition do_nothing() {
        let result: u32 = governance.aleo/main(2u32, 3u32);
        assert_eq(result, 3u32);
    }
}
