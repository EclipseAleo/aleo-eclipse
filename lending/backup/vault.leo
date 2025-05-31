// File: eclipse_lending_usda_vault.aleo
// USDA Vault – dépôt de collatéraux, emprunts, et liquidation à 105%

import token_registry.aleo;
import eclipse_oracle_aggregate_4.aleo;

program eclipse_lending_usda_vault.aleo {
    // --------------------------------------------------------------------
    // Constantes (à ajuster)
    // --------------------------------------------------------------------
    const ADMIN:                address = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;
    const USDA_TOKEN_ID:        field   = 445566778899field;

    // Taux d’intérêt fixe pour la dette vault (3% APR)
    const VAULT_BORROW_RATE:    u128    = 30_000_000_000_000_000u128; // 0.03 * 1e18
    const VAULT_BLOCKS_PER_YEAR:u128    = 12_614_400u128;             // ≈2.5s/block ~12M blocks/an

    // Paramètres de collatéral
    struct CollateralParam {
        feed_id: field,
        ltv_min: u128,   // fact. 100×
        lltv:    u128,   // seuil liquidation, ici 105×
        paused:  bool
    }

    mapping allowed:          field   => CollateralParam;
    mapping collateral:       field   => u128;           // key = token_id ‖ user
    mapping debt_usda:        address => u128;

    // Mapping pour accrual de la dette
    mapping debt_index:       field   => u128;           // index cumulatif dette (1e18 fixe)
    mapping last_debt_accrual:field   => u64;            // dernier block d’accrual dette

    // --------------------------------------------------------------------
    // Helpers common
    // --------------------------------------------------------------------
    inline calculate_interest(
        rate_per_block: u128,
        delta_blocks:   u64
    ) -> u128 {
        // rate_per_block en 1e18 fixe
        return rate_per_block * (delta_blocks as u128) / 1_000_000_000_000_000_000u128;
    }

    inline check_admin(
        caller: address
    ) {
        assert(caller == ADMIN);
    }

    // ====================================================================
    // 1. Initialisation du Vault
    // ====================================================================
    async transition initialize(
        public caller: address
    ) -> Future {
        check_admin(caller);
        let f_reg: Future = token_registry.aleo/register_token(
            USDA_TOKEN_ID,
            567137312326300096786987u128,  // "USDA" en bytes-32
            1480805620u128,               // symbol
            18u8,
            1_000_000_000_000000000u128,
            false,
            ADMIN
        );
        return finalize_initialize(f_reg);
    }

    async function finalize_initialize(
        f_reg: Future
    ) {
        f_reg.await();
        // Initialise index et horodatage de la dette
        debt_index.set(USDA_TOKEN_ID,      1_000_000_000_000_000_000u128);
        last_debt_accrual.set(USDA_TOKEN_ID, block.height as u64);
    }

    // ====================================================================
    // 2. Ajouter un token en collatéral
    // ====================================================================
    async transition add_collateral_token(
        public token_id: field,
        public feed_id:  field,
        public ltv_min:  u128,
        public lltv:     u128,
        public caller:   address
    ) -> Future {
        return finalize_add_collateral_token(token_id, feed_id, ltv_min, lltv, caller);
    }

    async function finalize_add_collateral_token(
        public token_id: field,
        public feed_id:  field,
        public ltv_min:  u128,
        public lltv:     u128,
        public caller:   address
    ) {
        check_admin(caller);
        assert(ltv_min > lltv);
        let cfg: CollateralParam = CollateralParam{
            feed_id: feed_id,
            ltv_min: ltv_min,
            lltv:    lltv,
            paused:  false
        };
        allowed.set(token_id, cfg);
    }

    // ====================================================================
    // 3. Dépôt de collatéral
    // ====================================================================
    async transition deposit(
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
        return finalize_deposit(f_move, token_id, amount, caller);
    }

    async function finalize_deposit(
        f_move:          Future,
        public token_id: field,
        public amount:   u128,
        public caller:   address
    ) {
        f_move.await();
        let cfg: CollateralParam = allowed.get(token_id);
        assert(!cfg.paused);
        assert(amount > 0u128);
        let key: field = token_id + (caller as field);
        let prev: u128 = collateral.get_or_use(key, 0u128);
        collateral.set(key, prev + amount);
    }

    // ====================================================================
    // 4. Retrait de collatéral (vérifie la santé)
    // ====================================================================
    async transition withdraw(
        public token_id: field,
        public amount:   u128,
        public caller:   address
    ) -> Future {
        let f_out: Future = token_registry.aleo/transfer_public(
            token_id,
            caller,
            amount
        );
        return finalize_withdraw(f_out, token_id, amount, caller);
    }

    async function finalize_withdraw(
        f_out:           Future,
        public token_id: field,
        public amount:   u128,
        public caller:   address
    ) {
        let key: field = token_id + (caller as field);
        let prev: u128 = collateral.get_or_use(key, 0u128);
        assert(prev >= amount);
        let cfg: CollateralParam = allowed.get(token_id);
        let debt_before: u128 = debt_usda.get_or_use(caller, 0u128);
        // Accrual de la dette
        let last_blk: u64 = last_debt_accrual.get_or_use(USDA_TOKEN_ID, 0u64);
        let now_blk:  u64 = block.height as u64;
        let delta:    u64 = now_blk - last_blk;
        if (delta > 0u64) {
            let rate_per_block: u128 = VAULT_BORROW_RATE / VAULT_BLOCKS_PER_YEAR;
            let interest: u128      = calculate_interest(rate_per_block, delta);
            let idx_old: u128       = debt_index.get_or_use(USDA_TOKEN_ID, 1_000_000_000_000_000_000u128);
            let idx_new: u128       = idx_old * (1_000_000_000_000_000_000u128 + interest) / 1_000_000_000_000_000_000u128;
            debt_index.set(USDA_TOKEN_ID, idx_new);
            last_debt_accrual.set(USDA_TOKEN_ID, now_blk);
        }
        let idx: u128 = debt_index.get_or_use(USDA_TOKEN_ID, 1_000_000_000_000_000_000u128);
        let debt: u128 = debt_before * idx / 1_000_000_000_000_000_000u128;
        if (debt > 0u128) {
            let price: u128  = eclipse_oracle_aggregate_4.aleo/latest_price.get(cfg.feed_id);
            let remain: u128 = prev - amount;
            let coll_val:u128= remain * price;
            assert(coll_val * 100u128 >= debt * cfg.ltv_min);
        }
        collateral.set(key, prev - amount);
        f_out.await();
    }

    // ====================================================================
    // 5. Emission de USDA (mint) après dépôt
    // ====================================================================
    async transition mint(
        public token_id: field,
        public usda_out: u128,
        public caller:   address
    ) -> Future {
        let f_mint: Future = token_registry.aleo/mint_public(
            USDA_TOKEN_ID,
            caller,
            usda_out,
            0u32
        );
        return finalize_mint(f_mint, token_id, usda_out, caller);
    }

    async function finalize_mint(
        f_mint:          Future,
        public token_id: field,
        public usda_out: u128,
        public caller:   address
    ) {
        f_mint.await();
        let cfg: CollateralParam = allowed.get(token_id);
        assert(!cfg.paused);
        let key: field = token_id + (caller as field);
        let coll_amt: u128 = collateral.get_or_use(key, 0u128);
        assert(coll_amt > 0u128);
        let price: u128 = eclipse_oracle_aggregate_4.aleo/latest_price.get(cfg.feed_id);
        let coll_val: u128 = coll_amt * price;
        // Accrual de la dette
        let last_blk: u64 = last_debt_accrual.get_or_use(USDA_TOKEN_ID, 0u64);
        let now_blk:  u64 = block.height as u64;
        let delta:    u64 = now_blk - last_blk;
        if (delta > 0u64) {
            let rate_per_block: u128 = VAULT_BORROW_RATE / VAULT_BLOCKS_PER_YEAR;
            let interest: u128      = calculate_interest(rate_per_block, delta);
            let idx_old: u128       = debt_index.get_or_use(USDA_TOKEN_ID, 1_000_000_000_000_000_000u128);
            let idx_new: u128       = idx_old * (1_000_000_000_000_000_000u128 + interest) / 1_000_000_000_000_000_000u128;
            debt_index.set(USDA_TOKEN_ID, idx_new);
            last_debt_accrual.set(USDA_TOKEN_ID, now_blk);
        }
        let idx: u128        = debt_index.get_or_use(USDA_TOKEN_ID, 1_000_000_000_000_000_000u128);
        let prev_debt: u128  = debt_usda.get_or_use(caller, 0u128);
        let owed: u128       = prev_debt * idx / 1_000_000_000_000_000_000u128;
        let new_debt: u128   = owed + usda_out;
        assert(coll_val * 100u128 >= new_debt * cfg.ltv_min);
        debt_usda.set(caller, new_debt);
    }

    // ====================================================================
    // 6. Remboursement de USDA (burn)
    // ====================================================================
    async transition burn(
        public usda_in: u128,
        public caller:  address
    ) -> Future {
        let f_burn: Future = token_registry.aleo/burn_public(
            USDA_TOKEN_ID,
            caller,
            usda_in
        );
        return finalize_burn(f_burn, usda_in, caller);
    }

    async function finalize_burn(
        f_burn:          Future,
        public usda_in: u128,
        public caller:   address
    ) {
        f_burn.await();
        // Accrual de la dette
        let last_blk: u64 = last_debt_accrual.get_or_use(USDA_TOKEN_ID, 0u64);
        let now_blk:  u64 = block.height as u64;
        let delta:    u64 = now_blk - last_blk;
        if (delta > 0u64) {
            let rate_per_block: u128 = VAULT_BORROW_RATE / VAULT_BLOCKS_PER_YEAR;
            let interest: u128      = calculate_interest(rate_per_block, delta);
            let idx_old: u128       = debt_index.get_or_use(USDA_TOKEN_ID, 1_000_000_000_000_000_000u128);
            let idx_new: u128       = idx_old * (1_000_000_000_000_000_000u128 + interest) / 1_000_000_000_000_000_000u128;
            debt_index.set(USDA_TOKEN_ID, idx_new);
            last_debt_accrual.set(USDA_TOKEN_ID, now_blk);
        }
        let idx: u128        = debt_index.get_or_use(USDA_TOKEN_ID, 1_000_000_000_000_000_000u128);
        let prev_debt: u128  = debt_usda.get_or_use(caller, 0u128);
        let owed: u128       = prev_debt * idx / 1_000_000_000_000_000_000u128;
        assert(owed >= usda_in);
        let new_debt: u128   = owed - usda_in;
        debt_usda.set(caller, new_debt);
    }

    // ====================================================================
    // 7. Liquidation si santé < 105 %
    // ====================================================================
    async transition liquidate(
        public victim:             address,
        public token_id:           field,
        public collateral_amt_in:  u128,
        public debt_amt_in:        u128
    ) -> Future {
        // dummy future pour respecter le pattern (pas de mapping ici)
        let f_dummy: Future = token_registry.aleo/mint_public(
            USDA_TOKEN_ID,
            ADMIN,
            0u128,
            0u32
        );
        // transfert du collatéral au liquidateur
        let f_out: Future = token_registry.aleo/transfer_public(
            token_id,
            self.caller,
            collateral_amt_in
        );
        return finalize_liquidate(
            f_dummy,
            f_out,
            victim,
            token_id,
            collateral_amt_in,
            debt_amt_in
        );
    }

    async function finalize_liquidate(
        f_dummy:                 Future,
        f_out:                   Future,
        public victim:           address,
        public token_id:         field,
        public collateral_amt_in:u128,
        public debt_amt_in:      u128
    ) {
        f_dummy.await();

        // Lecture de l’état
        let key: field = token_id + (victim as field);
        let stored_coll: u128 = collateral.get_or_use(key, 0u128);
        let stored_debt:  u128 = debt_usda.get_or_use(victim, 0u128);
        assert(stored_coll == collateral_amt_in);
        assert(stored_debt == debt_amt_in);

        // Vérifie la config et le prix
        let cfg: CollateralParam = allowed.get(token_id);
        assert(!cfg.paused);
        let price: u128 = eclipse_oracle_aggregate_4.aleo/latest_price.get(cfg.feed_id);

        // Liquidation health check
        let coll_val: u128 = stored_coll * price;
        assert(coll_val * 100u128 < stored_debt * cfg.lltv);

        // Efface l’état du débiteur
        collateral.set(key, 0u128);
        debt_usda.set(victim, 0u128);

        f_out.await();
    }

    // ====================================================================

    async transition deposit_priv(
        public token_id: field,
        private amount:  u128,
        public caller:   address
    ) -> Future {
        // Le montant est privé, seul caller et token_id restent publics.
        let (tkn, f): (token_registry.aleo/Token, Future) =
            token_registry.aleo/transfer_public_to_private(
                token_id,
                caller,
                amount,
                false
            );
        return finalize_deposit_priv(f, token_id, amount, caller);
    }
    async function finalize_deposit_priv(
        f: Future,
        public token_id: field,
        public amount:  u128,
        public caller:   address
    ) {
        f.await();
        // Réutilise la logique existante de mapping
        let key: field = token_id + (caller as field);
        let prev: u128 = collateral.get_or_use(key, 0u128);
        collateral.set(key, prev + amount);
    }


    // 8b. Retrait privé de collatéral
    async transition withdraw_priv(
        public token_id: field,
        private amount:   u128,
        public caller:    address
    ) -> Future {
        let f: Future = token_registry.aleo/transfer_public(
            token_id,
            caller,
            amount
        );
        return finalize_withdraw_priv(f, token_id, amount, caller);
    }


    async function finalize_withdraw_priv(
        f: Future,
        public token_id: field,
        public amount:   u128,    // ← visibility changed here
        public caller:    address
    ) {
        // 1) Vérifs et mise à jour du collatéral
        let key: field     = token_id + (caller as field);
        let prev: u128     = collateral.get_or_use(key, 0u128);
        assert(prev >= amount);

        let cfg: CollateralParam = allowed.get(token_id);
        let debt_before: u128    = debt_usda.get_or_use(caller, 0u128);

        // → accrus debt_index & last_debt_accrual comme dans finalize_withdraw
        let last_blk: u64 = last_debt_accrual.get_or_use(USDA_TOKEN_ID, 0u64);
        let now_blk:  u64 = block.height as u64;
        let delta:    u64 = now_blk - last_blk;
        if (delta > 0u64) {
            let rate_per_block: u128 = VAULT_BORROW_RATE / VAULT_BLOCKS_PER_YEAR;
            let interest: u128      = calculate_interest(rate_per_block, delta);
            let idx_old: u128       = debt_index.get_or_use(USDA_TOKEN_ID, 1_000_000_000_000_000_000u128);
            let idx_new: u128       = idx_old * (1_000_000_000_000_000_000u128 + interest)
                                    / 1_000_000_000_000_000_000u128;
            debt_index.set(USDA_TOKEN_ID, idx_new);
            last_debt_accrual.set(USDA_TOKEN_ID, now_blk);
        }
        let idx: u128 = debt_index.get_or_use(USDA_TOKEN_ID, 1_000_000_000_000_000_000u128);
        let debt: u128 = debt_before * idx / 1_000_000_000_000_000_000u128;
        if (debt > 0u128) {
            let price: u128  = eclipse_oracle_aggregate_4.aleo/latest_price.get(cfg.feed_id);
            let remain: u128 = prev - amount;
            let coll_val:u128= remain * price;
            assert(coll_val * 100u128 >= debt * cfg.ltv_min);
        }

        // 2) On met à jour le mapping
        collateral.set(key, prev - amount);

        // 3) Enfin, on exécute la sortie des tokens
        f.await();
    }

    // 8c. Mint privé de USDA (borrow)
    async transition mint_priv(
        public token_id: field,
        private usda_out: u128,
        public caller:    address
    ) -> Future {
        let f: Future = token_registry.aleo/mint_public(
            USDA_TOKEN_ID,
            caller,
            usda_out,
            0u32
        );
        return finalize_mint_priv(f, token_id, usda_out, caller);
    }

    async function finalize_mint_priv(
        f: Future,
        public token_id: field,
        public usda_out:  u128,
        public caller:    address
    ) {
        f.await();

        // 1) Vérifie que le collatéral est bien déposé
        let cfg: CollateralParam = allowed.get(token_id);
        assert(!cfg.paused);

        let key: field     = token_id + (caller as field);
        let coll_amt: u128 = collateral.get_or_use(key, 0u128);
        assert(coll_amt > 0u128);

        // 2) Accrual de la dette
        let last_blk: u64 = last_debt_accrual.get_or_use(USDA_TOKEN_ID, 0u64);
        let now_blk:  u64 = block.height as u64;
        let delta:    u64 = now_blk - last_blk;
        if (delta > 0u64) {
            let rate_per_block: u128 = VAULT_BORROW_RATE / VAULT_BLOCKS_PER_YEAR;
            let interest: u128      = calculate_interest(rate_per_block, delta);
            let idx_old: u128       = debt_index.get_or_use(USDA_TOKEN_ID, 1_000_000_000_000_000_000u128);
            let idx_new: u128       = idx_old * (1_000_000_000_000_000_000u128 + interest)
                                    / 1_000_000_000_000_000_000u128;
            debt_index.set(USDA_TOKEN_ID, idx_new);
            last_debt_accrual.set(USDA_TOKEN_ID, now_blk);
        }
        let idx: u128        = debt_index.get_or_use(USDA_TOKEN_ID, 1_000_000_000_000_000_000u128);
        let prev_debt: u128  = debt_usda.get_or_use(caller, 0u128);
        let owed: u128       = prev_debt * idx / 1_000_000_000_000_000_000u128;
        let new_debt: u128   = owed + usda_out;

        // 3) Check de santé puis mise à jour de la dette
        let price: u128   = eclipse_oracle_aggregate_4.aleo/latest_price.get(cfg.feed_id);
        let coll_val:u128 = coll_amt * price;
        assert(coll_val * 100u128 >= new_debt * cfg.ltv_min);

        debt_usda.set(caller, new_debt);
    }



    // 8d. Burn privé de USDA (repay)
    async transition burn_priv(
        private usda_in: u128,
        public caller:   address
    ) -> Future {
        let f: Future = token_registry.aleo/burn_public(
            USDA_TOKEN_ID,
            caller,
            usda_in
        );
        return finalize_burn_priv(f, usda_in, caller);
    }

    async function finalize_burn_priv(
        f: Future,
        public usda_in:  u128,    // ← visibility changed ici
        public caller:   address
    ) {
        f.await();
        // --- même logique que dans finalize_burn original ---
        let last_blk: u64 = last_debt_accrual.get_or_use(USDA_TOKEN_ID, 0u64);
        let now_blk:  u64 = block.height as u64;
        let delta:    u64 = now_blk - last_blk;
        if (delta > 0u64) {
            let rate_per_block: u128 = VAULT_BORROW_RATE / VAULT_BLOCKS_PER_YEAR;
            let interest: u128      = calculate_interest(rate_per_block, delta);
            let idx_old: u128       = debt_index.get_or_use(USDA_TOKEN_ID, 1_000_000_000_000_000_000u128);
            let idx_new: u128       = idx_old * (1_000_000_000_000_000_000u128 + interest)
                                    / 1_000_000_000_000_000_000u128;
            debt_index.set(USDA_TOKEN_ID, idx_new);
            last_debt_accrual.set(USDA_TOKEN_ID, now_blk);
        }
        let idx: u128        = debt_index.get_or_use(USDA_TOKEN_ID, 1_000_000_000_000_000_000u128);
        let prev_debt: u128  = debt_usda.get_or_use(caller, 0u128);
        let owed: u128       = prev_debt * idx / 1_000_000_000_000_000_000u128;
        assert(owed >= usda_in);
        let new_debt: u128   = owed - usda_in;
        debt_usda.set(caller, new_debt);
    }
}