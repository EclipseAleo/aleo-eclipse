import token_registry.aleo;
import eclipse_oracle_aggregate_2.aleo;
import eclipse_lending_auction.aleo;

program eclipse_lending_usda_vault.aleo {

    const ADMIN: address = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;

    const USDA_TOKEN_ID: field = 445566778899field;
    const USDA_NAME: u128 = 567137312326300096786987u128;
    const USDA_SYMBOL: u128 = 1480805620u128;
    const USDA_DECIMALS: u8 = 18u8;
    const USDA_MAX_SUPPLY: u128 = 1000000000000000u128;

    struct CollateralParam {
        feed_id: field,
        ltv_min: u128,
        lltv: u128,
        paused: bool
    }

    mapping allowed: field => CollateralParam;
    mapping collateral: field => u128;
    mapping debt_usda: address => u128;

    async transition initialize(public caller: address) -> Future {
        assert(caller == ADMIN);
        let fut_reg: Future = token_registry.aleo/register_token(
            USDA_TOKEN_ID,
            USDA_NAME,
            USDA_SYMBOL,
            USDA_DECIMALS,
            USDA_MAX_SUPPLY,
            false,
            ADMIN
        );
        return finalize_initialize(fut_reg);
    }

    async function finalize_initialize(fut_reg: Future) {
        fut_reg.await();
    }

    async transition add_collateral_token(
        public token_id: field,
        public feed_id: field,
        public ltv_min: u128,
        public lltv: u128,
        public caller: address
    ) -> Future {
        return finalize_add_collateral_token(token_id, feed_id, ltv_min, lltv, caller);
    }

    async function finalize_add_collateral_token(
        public token_id: field,
        public feed_id: field,
        public ltv_min: u128,
        public lltv: u128,
        public caller: address
    ) {
        assert(caller == ADMIN);
        assert(ltv_min > lltv);
        let cfg: CollateralParam = CollateralParam{
            feed_id: feed_id,
            ltv_min: ltv_min,
            lltv: lltv,
            paused: false
        };
        allowed.set(token_id, cfg);
    }

    async transition deposit(
        public token_id: field,
        public amount: u128,
        public caller: address
    ) -> Future {
        let (temp, fut_move): (token_registry.aleo/Token, Future) =
            token_registry.aleo/transfer_public_to_private(token_id, caller, amount, false);
        return finalize_deposit(fut_move, token_id, amount, caller);
    }

    async function finalize_deposit(
        fut_move: Future,
        public token_id: field,
        public amount: u128,
        public caller: address
    ) {
        fut_move.await();
        let cfg: CollateralParam = allowed.get(token_id);
        assert(!cfg.paused);
        assert(amount > 0u128);
        let key: field = token_id + (caller as field);
        let prev: u128 = collateral.get_or_use(key, 0u128);
        collateral.set(key, prev + amount);
    }

    async transition withdraw(
        public token_id: field,
        public amount: u128,
        public caller: address
    ) -> Future {
        let fut_out: Future = token_registry.aleo/transfer_public(token_id, caller, amount);
        return finalize_withdraw(fut_out, token_id, amount, caller);
    }

    async function finalize_withdraw(
        fut_out: Future,
        public token_id: field,
        public amount: u128,
        public caller: address
    ) {
        let key: field = token_id + (caller as field);
        let prev: u128 = collateral.get_or_use(key, 0u128);
        assert(prev >= amount);
        let cfg: CollateralParam = allowed.get(token_id);
        let debt: u128 = debt_usda.get_or_use(caller, 0u128);
        if (debt > 0u128) {
            let price: u128 = eclipse_oracle_aggregate_2.aleo/latest_price.get(cfg.feed_id);
            let remain: u128 = prev - amount;
            let coll_val: u128 = remain * price;
            assert(coll_val * 100u128 >= debt * cfg.ltv_min);
        }
        collateral.set(key, prev - amount);
        fut_out.await();
    }

    async transition mint(
        public token_id: field,
        public usda_out: u128,
        public caller: address
    ) -> Future {
        let fut_mint: Future = token_registry.aleo/mint_public(
            USDA_TOKEN_ID,
            caller,
            usda_out,
            0u32
        );
        return finalize_mint(fut_mint, token_id, usda_out, caller);
    }

    async function finalize_mint(
        fut_mint: Future,
        public token_id: field,
        public usda_out: u128,
        public caller: address
    ) {
        fut_mint.await();
        let cfg: CollateralParam = allowed.get(token_id);
        assert(!cfg.paused);
        let key: field = token_id + (caller as field);
        let coll_amt: u128 = collateral.get_or_use(key, 0u128);
        assert(coll_amt > 0u128);
        let price: u128 = eclipse_oracle_aggregate_2.aleo/latest_price.get(cfg.feed_id);
        let coll_val: u128 = coll_amt * price;
        let prev_debt: u128 = debt_usda.get_or_use(caller, 0u128);
        let new_debt: u128 = prev_debt + usda_out;
        assert(coll_val * 100u128 >= new_debt * cfg.ltv_min);
        debt_usda.set(caller, new_debt);
    }

    async transition burn(
        public usda_in: u128,
        public caller: address
    ) -> Future {
        let fut_burn: Future = token_registry.aleo/burn_public(USDA_TOKEN_ID, caller, usda_in);
        return finalize_burn(fut_burn, usda_in, caller);
    }

    async function finalize_burn(
        fut_burn: Future,
        public usda_in: u128,
        public caller: address
    ) {
        fut_burn.await();
        let prev: u128 = debt_usda.get_or_use(caller, 0u128);
        assert(prev >= usda_in);
        debt_usda.set(caller, prev - usda_in);
    }

    async transition liquidate(
        public victim: address,
        public token_id: field,
        public collateral_amt_in: u128,
        public debt_amt_in: u128,
        public caller: address
    ) -> Future {
        let fut_auc: Future = eclipse_lending_auction.aleo/start_auction(
            victim,
            token_id,
            collateral_amt_in,
            debt_amt_in,
            caller
        );
        return finalize_liquidate(fut_auc, victim, token_id, collateral_amt_in, debt_amt_in);
    }

    async function finalize_liquidate(
        fut_auc: Future,
        public victim: address,
        public token_id: field,
        public coll_amt: u128,
        public debt_amt: u128
    ) {
        let key: field = token_id + (victim as field);
        let stored_coll: u128 = collateral.get_or_use(key, 0u128);
        let stored_debt: u128 = debt_usda.get_or_use(victim, 0u128);
        assert(stored_coll == coll_amt);
        assert(stored_debt == debt_amt);
        let cfg: CollateralParam = allowed.get(token_id);
        let price: u128 = eclipse_oracle_aggregate_2.aleo/latest_price.get(cfg.feed_id);
        let coll_val: u128 = coll_amt * price;
        assert(coll_val * 100u128 < debt_amt * cfg.lltv);
        collateral.set(key, 0u128);
        debt_usda.set(victim, 0u128);
        fut_auc.await();
    }
}
