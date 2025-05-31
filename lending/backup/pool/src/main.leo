// File: eclipse_lending_pair.aleo
// Pair TOKEN/USDA – gestion des dépôts, emprunts et remboursements
// Template Leo 2.5 – scission “async transition” / “finalize”

import token_registry.aleo;

program eclipse_lending_pair_template.aleo {
    // --------------------------------------------------------------------
    // Constantes du marché (à adapter)
    // --------------------------------------------------------------------
    const ADMIN:          address = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;
    const TOKEN_ID:       field   = 111111111111field;  // ID du token sous-jacent
    const USDA_ID:        field   = 222222222222field;  // ID du stable USDA
    const CTOKEN_ID:      field   = 333333333333field;  // cToken (représentation de la position)
    const CTOKEN_NAME:    u128    = 123456789012345678901234567890u128;
    const CTOKEN_SYMBOL:  u128    = 987654321098765432109876543210u128;
    const CTOKEN_DECIMALS:u8      = 8u8;
    const CTOKEN_SUPPLY_MAX:u128  = 1_000_000_000u128;

    // --------------------------------------------------------------------
    // Paramètres du modèle de taux d'intérêt (fixed-point 1e18)
    // --------------------------------------------------------------------
    const BASE_RATE:       u128 = 20_000_000_000_000_000u128;   //  2% APR
    const SLOPE1:          u128 =100_000_000_000_000_000u128;   // 10% APR jusqu'au kink
    const SLOPE2:          u128 =200_000_000_000_000_000u128;   // 20% APR au-delà du kink
    const KINK:            u128 =800_000_000_000_000_000u128;   // 80% utilisation
    const BLOCKS_PER_YEAR: u128 =1_120_000u128;                // ~28s/block ~1.12M blocks/an

    // --------------------------------------------------------------------
    // Storage
    // --------------------------------------------------------------------
    mapping total_supply:       field   => u128;   // montant total du TOKEN déposé
    mapping total_borrows:      field   => u128;   // montant total de USDA emprunté
    mapping last_accrual_block: field   => u64;    // dernier block d’accrual

    mapping supply_index:       field   => u128;   // index cumulatif fournisseur (1e18 fixe)
    mapping borrow_index:       field   => u128;   // index cumulatif emprunteur (1e18 fixe)

    // cToken-like: parts fongibles
    mapping total_shares:       field   => u128;   // total des parts émises
    mapping share_balance:      address => u128;   // parts détenues par l’utilisateur

    mapping supply_balance:     address => u128;   // quantité de TOKEN déposée par l’utilisateur (underlying)
    mapping borrow_balance:     address => u128;   // dette USDA de l’utilisateur

    // --------------------------------------------------------------------
    // Inline / pure helpers
    // --------------------------------------------------------------------
    inline calculate_interest(
        rate_per_block: u128,
        delta_blocks:   u64
    ) -> u128 {
        // rate_per_block en 1e18 fixe
        return rate_per_block * (delta_blocks as u128) / 1_000_000_000_000_000_000u128;
    }

    function check_admin(
        caller: address
    ) {
        assert(caller == ADMIN);
    }

    // ====================================================================
    // 1. Initialisation du marché
    // ====================================================================
    async transition initialise(
        public caller:       address,
        public initial_rate: u128
    ) -> Future {
        check_admin(caller);
        let f_reg: Future = token_registry.aleo/register_token(
            CTOKEN_ID,
            CTOKEN_NAME,
            CTOKEN_SYMBOL,
            CTOKEN_DECIMALS,
            CTOKEN_SUPPLY_MAX,
            false,
            caller
        );
        return finalize_initialise(f_reg, caller, initial_rate);
    }

    async function finalize_initialise(
        f_reg:            Future,
        public caller:    address,
        public initial_rate: u128
    ) {
        f_reg.await();
        total_supply.set(TOKEN_ID,      0u128);
        total_borrows.set(TOKEN_ID,     0u128);
        supply_index.set(TOKEN_ID,      initial_rate);
        borrow_index.set(TOKEN_ID,      initial_rate);
        total_shares.set(TOKEN_ID,      0u128);
        last_accrual_block.set(TOKEN_ID, block.height as u64);
    }

    // ====================================================================
    // 2. Accumulation des intérêts (dynamic rate)
    // ====================================================================
    async transition accrue(
        public caller:   address,
        public token_id: field
    ) -> Future {
        // dummy pour pattern async
        let f_dummy: Future = token_registry.aleo/mint_public(
            CTOKEN_ID,
            ADMIN,
            0u128,
            0u32
        );
        return finalize_accrue(f_dummy, token_id);
    }

    async function finalize_accrue(
        f_dummy:        Future,
        public token_id: field
    ) {
        f_dummy.await();
        let last_blk: u64 = last_accrual_block.get_or_use(token_id, 0u64);
        let now_blk:  u64 = block.height as u64;
        let delta:    u64 = now_blk - last_blk;
        if (delta > 0u64) {
            // --- calcul du taux dynamique en utilisation ---
            let cash:    u128 = total_supply.get_or_use(token_id, 0u128);
            let borrows: u128 = total_borrows.get_or_use(token_id, 0u128);


            // 1) Calcul de l’utilisation en 1e18 fixe
            let utilization: u128 =
                cash == 0u128
                ? 0u128
                : borrows * 1_000_000_000_000_000_000u128 / cash;

            // 2) Calcul de l’APR selon kink
            let apr: u128 =
                utilization <= KINK
                ? BASE_RATE + utilization * SLOPE1 / 1_000_000_000_000_000_000u128
                : BASE_RATE
                + KINK * SLOPE1 / 1_000_000_000_000_000_000u128
                + (utilization - KINK) * SLOPE2 / 1_000_000_000_000_000_000u128;

            // 3) Conversion en rate_per_block
            let rate_per_block: u128 = apr / BLOCKS_PER_YEAR;

            let interest:       u128 = calculate_interest(rate_per_block, delta);
            let interest_amt:   u128 = borrows * interest;

            // Mise à jour des totaux et des indices
            total_borrows.set(token_id, borrows + interest_amt);
            let si: u128 = supply_index.get_or_use(token_id, 0u128);
            let bi: u128 = borrow_index.get_or_use(token_id, 0u128);
            supply_index.set(token_id, si + interest);
            borrow_index.set(token_id, bi + interest);
            last_accrual_block.set(token_id, now_blk);
        }
    }

    // ====================================================================
    // 3. Dépôt (supply) de TOKEN → mint de parts
    // ====================================================================
    async transition supply(
        public token_id: field,
        public amount:   u128,
        public caller:   address
    ) -> Future {
        let (temp, f_move): (token_registry.aleo/Token, Future) =
            token_registry.aleo/transfer_public_to_private(
                token_id,
                caller,
                amount,
                false
            );
        return finalize_supply(f_move, token_id, amount, caller);
    }

    async function finalize_supply(
        f_move:          Future,
        public token_id: field,
        public amount:   u128,
        public caller:   address
    ) {
        f_move.await();
        // 1) Met à jour le dépôt underlying
        let prev_under: u128 = supply_balance.get_or_use(caller, 0u128);
        supply_balance.set(caller, prev_under + amount);
        let tot_under:  u128 = total_supply.get_or_use(token_id, 0u128);
        total_supply.set(token_id, tot_under + amount);

        // 2) Mint des cTokens (parts)
        let si: u128 = supply_index.get_or_use(token_id, 1_000_000_000_000_000_000u128);
        let shares: u128 = amount * 1_000_000_000_000_000_000u128 / si;
        let prev_sh: u128 = share_balance.get_or_use(caller, 0u128);
        share_balance.set(caller, prev_sh + shares);
        let tot_sh: u128 = total_shares.get_or_use(token_id, 0u128);
        total_shares.set(token_id, tot_sh + shares);
    }

    // ====================================================================
    // 4. Emprunt (borrow) de USDA
    // ====================================================================
    async transition borrow(
        public token_id: field,
        public amount:   u128,
        public caller:   address
    ) -> Future {
        let f_mint: Future = token_registry.aleo/mint_public(
            USDA_ID,
            caller,
            amount,
            0u32
        );
        return finalize_borrow(f_mint, token_id, amount, caller);
    }

    async function finalize_borrow(
        f_mint:          Future,
        public token_id: field,
        public amount:   u128,
        public caller:   address
    ) {
        f_mint.await();
        let prev: u128 = borrow_balance.get_or_use(caller, 0u128);
        borrow_balance.set(caller, prev + amount);
        let tot:  u128 = total_borrows.get_or_use(token_id, 0u128);
        total_borrows.set(token_id, tot + amount);
    }

    // ====================================================================
    // 5. Remboursement (repay) de USDA
    // ====================================================================
    async transition repay(
        public usda_amount: u128,
        public caller:      address
    ) -> Future {
        let f_move: Future = token_registry.aleo/transfer_public(
            USDA_ID,
            caller,
            usda_amount
        );
        return finalize_repay(f_move, usda_amount, caller);
    }

    async function finalize_repay(
        f_move:          Future,
        public usda_amount: u128,
        public caller:   address
    ) {
        f_move.await();
        let prev: u128 = borrow_balance.get_or_use(caller, 0u128);
        assert(prev >= usda_amount);
        borrow_balance.set(caller, prev - usda_amount);
    }

    // ====================================================================
    // 6. Retrait (withdraw) de TOKEN → burn de parts
    // ====================================================================
    async transition withdraw(
        public token_id: field,
        public amount:   u128,
        public caller:   address
    ) -> Future {
        let f_move: Future = token_registry.aleo/transfer_public(
            token_id,
            caller,
            amount
        );
        return finalize_withdraw(f_move, token_id, amount, caller);
    }

    async function finalize_withdraw(
        f_move:          Future,
        public token_id: field,
        public amount:   u128,
        public caller:   address
    ) {
        f_move.await();
        // 1) Met à jour le dépôt underlying
        let prev_under: u128 = supply_balance.get_or_use(caller, 0u128);
        assert(prev_under >= amount);
        supply_balance.set(caller, prev_under - amount);
        let tot_under:  u128 = total_supply.get_or_use(token_id, 0u128);
        total_supply.set(token_id, tot_under - amount);

        // 2) Burn des cTokens (parts)
        let si: u128 = supply_index.get_or_use(token_id, 1_000_000_000_000_000_000u128);
        let shares: u128 = amount * 1_000_000_000_000_000_000u128 / si;
        let prev_sh: u128 = share_balance.get(caller);
        assert(prev_sh >= shares);
        share_balance.set(caller, prev_sh - shares);
        let tot_sh: u128 = total_shares.get_or_use(token_id, 0u128);
        total_shares.set(token_id, tot_sh - shares);
    }
}
