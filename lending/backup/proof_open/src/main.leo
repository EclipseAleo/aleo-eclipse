// proof_circuits.leo
// Leo programs defining two circuits for the lending vault, using Poseidon4 hashing.

// ---------------------------------------------------------------------
// 1. Proof of Healthy Position (ProofOpen / ProofHealthy)
// ---------------------------------------------------------------------
program proof_open.aleo {
    // Transition to prove that a position is healthy and correctly parameterized
    transition prove_health(
        // Public inputs
        public commitment:   field,   // hashed record: Poseidon4(coll_amt, debt_amt, salt)
        public P_liq:        u128,    // exact liquidation price = debt_amt * lltv / (coll_amt * 100)
        public max_debt_cap: u128,    // upper bound on debt_amt
        public P_market:     u128,    // current oracle price
        public ltv_min:      u128,    // minimum LTV factor (e.g. 150)
        public lltv:         u128,    // liquidation LTV factor (e.g. 105)
        // Private inputs
        private coll_amt:    u128,    // collateral amount
        private debt_amt:    u128,    // debt amount
        private salt:        field    // random salt for commitment
    ) {
        // Recompute the Poseidon4 commitment from private values
        let computed: field = Poseidon4::hash_to_field([
            coll_amt as field,
            debt_amt as field,
            salt,
            0field          // pad to 4 inputs
        ]);
        assert(computed == commitment);

        // Check that the position is healthy:
        // coll_amt * P_market * 100 >= debt_amt * ltv_min
        let left:  u128 = coll_amt * P_market * 100u128;
        let right: u128 = debt_amt * ltv_min;
        assert(left >= right);

        // Check that P_liq is exactly the liquidation price:
        // P_liq * coll_amt * 100 == debt_amt * lltv
        let denom:    u128 = coll_amt * 100u128;
        let numer:    u128 = debt_amt * lltv;
        let check_liq:u128 = P_liq * denom;
        assert(check_liq == numer);

        // Ensure the max_debt_cap covers the actual debt
        assert(max_debt_cap >= debt_amt);
    }
}


