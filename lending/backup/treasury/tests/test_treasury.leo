// The 'test_treasury' test program.
import treasury.aleo;
program test_treasury.aleo {
    @test
    script test_it() {
        let result: u32 = treasury.aleo/main(1u32, 2u32);
        assert_eq(result, 3u32);
    }

    @test
    @should_fail
    transition do_nothing() {
        let result: u32 = treasury.aleo/main(2u32, 3u32);
        assert_eq(result, 3u32);
    }
}
