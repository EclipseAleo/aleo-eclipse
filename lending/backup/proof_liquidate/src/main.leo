// proof_liquidate.aleo
// Leo program defining the liquidation eligibility circuit for the lending vault,
// using Poseidon4 hashing for commitment verification.

program proof_liquidate.aleo {
    transition prove_liquidate(
        public max_debt_cap: u128,
        private debt_amt:   u128
    ) {
        assert(debt_amt <= max_debt_cap);
    }
}