// The 'test_proof_open' test program.
import proof_open.aleo;
program test_proof_open.aleo {
    @test
    script test_it() {
        let result: u32 = proof_open.aleo/main(1u32, 2u32);
        assert_eq(result, 3u32);
    }

    @test
    @should_fail
    transition do_nothing() {
        let result: u32 = proof_open.aleo/main(2u32, 3u32);
        assert_eq(result, 3u32);
    }
}
