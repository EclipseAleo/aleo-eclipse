import token_registry.aleo;
import eclipse_oracle_aggregate_4.aleo;

program eclipse_lending_usda_vault.aleo {
    const ADMIN:            address = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;
    const USDA_TOKEN_ID:    field   = 445566778899field;
    const PROVISION_FACTOR: u128    = 125u128;    

    struct CollateralParam {
        feed_id: field,
        lltv:    u128
    }

    mapping allowed: field => CollateralParam;
    mapping priv_commit: u64 => field;

    struct PositionMeta {
        token_id:  field,
        coll_amt:  u128,
        debt_amt:  u128,
        price_liq: u128,
        max_debt:  u128,
        t_last:    u64
    }
    mapping metas: u64 => PositionMeta;
    mapping next_id: field => u64;

    record Position {
        owner:    address,
        token_id: field,
        id:       u64
    }

    inline check_admin(caller: address) {
        assert(caller == ADMIN);
    }

    // --------------------------------------------------------------------
    // 1 Initialisation (enregistre USDA)
    // --------------------------------------------------------------------
    async transition initialize(public caller: address) -> Future {
        check_admin(caller);
        let future_reg: Future = token_registry.aleo/register_token(
            USDA_TOKEN_ID,
            567137312326300096786987u128, // "USDA"
            1480805620u128,               // symbol
            18u8,
            1_000_000_000_000000000u128,  // max supply
            false,
            ADMIN
        );
        return finalize_initialize(future_reg);
    }
    async function finalize_initialize(future_reg: Future) {
        future_reg.await();
        next_id.set(0field, 0u64);
    }

    // --------------------------------------------------------------------
    // 2 Dépôt de collatéral
    // --------------------------------------------------------------------
    async transition deposit(
        public token_id: field,
        public amount: u128,
        public price: u128,
        public last_id : u64,
        private caller: address
    ) -> (Position, Future) {
        let (tok, future_mv): (token_registry.aleo/Token, Future) =
            token_registry.aleo/transfer_public_to_private(
                token_id, self.caller, amount, false
            );

        let new_id: u64 = last_id + 1u64;

        let pos: Position = Position{
            owner: caller,
            token_id,
            id: new_id
        };
        return (pos, finalize_deposit(future_mv, pos.id, pos.token_id, amount, price, token_id, new_id));
    }
    async function finalize_deposit(
        future_mv:     Future,
        public pos_id: u64,
        public pos_token_id: field,
        public amount: u128,
        public price:  u128,
        public token_id: field,
        public new_id: u64
    ) {
        let current:u64 = next_id.get_or_use(token_id, 0u64);
        assert(new_id == current + 1u64);
        future_mv.await();
        next_id.set(token_id, current+1u64);

        let commit: field = Poseidon4::hash_to_field([
            pos_id    as field,
            amount    as field,
            price     as field,
            0field
        ]);
        priv_commit.set(pos_id, commit);

        let cfg: CollateralParam = allowed.get(pos_token_id);
        let coll_val: u128 = amount * price;
        let price_liq: u128 = coll_val * cfg.lltv / 100u128;
        let max_debt:  u128 = coll_val * PROVISION_FACTOR / 100u128;

        metas.set(pos_id, PositionMeta{
            token_id:  pos_token_id,
            coll_amt:  amount,
            debt_amt:  0u128,
            price_liq: price_liq,
            max_debt:  max_debt,
            t_last:    block.height as u64
        });
    }

    // --------------------------------------------------------------------
    // 3 Emprunt (mint USDA)
    // --------------------------------------------------------------------
    async transition mint(
        public token_id: field,
        public usda_out: u128,
        public price:    u128,
        private pos:     Position,
    ) -> (Position, Future) {
        assert(pos.owner == self.caller);

        let future_mint: Future =
            token_registry.aleo/mint_public(
                USDA_TOKEN_ID, self.caller, usda_out, 0u32
            );
        return (pos, finalize_mint(future_mint, pos.id, pos.token_id, usda_out, price, token_id));
    }
    async function finalize_mint(
        future_mint: Future,
        public pos_id: u64,
        public pos_token_id: field,
        public out:   u128,
        public price: u128,
        public token_id: field
    ) {
        let cfg = allowed.get(token_id);
        let oracle_price: u128 = eclipse_oracle_aggregate_4.aleo/latest_price.get(cfg.feed_id);
        assert(price == oracle_price);
        future_mint.await();

        let meta = metas.get(pos_id);
        let coll_val: u128 = meta.coll_amt * price;
        let price_liq: u128 = coll_val * allowed.get(pos_token_id).lltv / 100u128;
        let max_debt:  u128 = coll_val * PROVISION_FACTOR           / 100u128;
        metas.set(pos_id, PositionMeta{
            token_id:  pos_token_id,
            coll_amt:  meta.coll_amt,
            debt_amt:  out,
            price_liq: price_liq,
            max_debt:  max_debt,
            t_last:    block.height as u64
        });
    }

    // --------------------------------------------------------------------
    // 4 Remboursement (burn USDA)
    // --------------------------------------------------------------------
    async transition burn(
        public token_id: field,
        public usda_in:  u128,
        public price:    u128,
        private pos:     Position
    ) -> (Position, Future) {
        assert(pos.owner == self.caller);
        let future_burn: Future =
            token_registry.aleo/burn_public(
                USDA_TOKEN_ID, self.caller, usda_in
            );
        return (pos, finalize_burn(future_burn, pos.id, pos.token_id, usda_in, price));
    }
    async function finalize_burn(
        future_burn: Future,
        public pos_id: u64,
        public pos_token_id: field,
        public in_:  u128,
        public price:u128,
    ) {
        let cfg          = allowed.get(pos_token_id);
        let oracle_price = eclipse_oracle_aggregate_4.aleo/latest_price.get(cfg.feed_id);
        assert(price == oracle_price);
        
        future_burn.await();

        let meta = metas.get(pos_id);
        assert(meta.debt_amt >= in_);

        let new_debt = meta.debt_amt - in_;
        let coll_val: u128 = meta.coll_amt * price;
        let price_liq: u128 = coll_val * allowed.get(pos_token_id).lltv / 100u128;
        let max_debt:  u128 = coll_val * PROVISION_FACTOR           / 100u128;
        metas.set(pos_id, PositionMeta{
            token_id:  pos_token_id,
            coll_amt:  meta.coll_amt,
            debt_amt:  new_debt,
            price_liq: price_liq,
            max_debt:  max_debt,
            t_last:    block.height as u64
        });

        let new_commit: field = Poseidon4::hash_to_field([
            pos_id    as field,
            meta.coll_amt  as field,
            new_debt as field,
            0field
        ]);
        priv_commit.set(pos_id, new_commit);
    }


    // --------------------------------------------------------------------
    // 5 Liquidation permissionless
    // --------------------------------------------------------------------
    mapping liquidation_refund: u64 => u128;
    mapping liquidation_collateral: u64 => u128;

    async transition liquidate(
        public id:        u64,
        public price:     u128,
        public usda_sent: u128,
        public debt_amt:   u128,
    ) -> Future {

        let future_burn: Future =
            token_registry.aleo/burn_public(
                USDA_TOKEN_ID, self.caller, debt_amt
            );
        return finalize_liquidate(future_burn, id, usda_sent, price);
    }
    async function finalize_liquidate(
        future_burn:    Future,
        public id:      u64,
        public usda_sent: u128,
        public price:   u128
    ) {
        future_burn.await();

        let meta: PositionMeta = Mapping::get(metas, id);
        assert(price <= meta.price_liq);

        let refund: u128 = usda_sent > meta.debt_amt ? usda_sent - meta.debt_amt : 0u128;

        Mapping::set(liquidation_refund,     id, refund);
        Mapping::set(liquidation_collateral, id, meta.coll_amt);

        Mapping::remove(priv_commit, id);
        Mapping::remove(metas,       id);
    }

    async transition claim_refund(
        public id:     u64,
        public refund: u128
    ) -> Future {
        let future_mint: Future =
            token_registry.aleo/mint_public(
                USDA_TOKEN_ID,
                self.caller,
                refund,
                0u32
            );
        return finalize_claim_refund(future_mint, id, refund);
    }

    async function finalize_claim_refund(
        future_mint: Future,
        public id:     u64,
        public refund: u128
    ) {
        future_mint.await();
        let stored: u128 = Mapping::get_or_use(liquidation_refund, id, 0u128);
        assert(refund <= stored);
        Mapping::remove(liquidation_refund, id);
    }

    async transition claim_collateral(
        public token_id: field,
        public id:       u64,
        public coll:     u128
    ) -> Future {
        let future_out: Future =
            token_registry.aleo/transfer_public(
                token_id,
                self.caller,
                coll
            );
        return finalize_claim_collateral(future_out, id, coll);
    }

    async function finalize_claim_collateral(
        future_out: Future,
        public id:  u64,
        public coll: u128
    ) {
        future_out.await();
        let stored: u128 = Mapping::get_or_use(liquidation_collateral, id, 0u128);
        assert(coll <= stored);
        Mapping::remove(liquidation_collateral, id);
    }
}













