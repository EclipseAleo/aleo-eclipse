import token_registry.aleo;
import eclipse_oracle_aggregate_2.aleo;
import credits.aleo;

program eclipse_lending_usda_vault_5.aleo {
    const ADMIN: address = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;
    const USDA_TOKEN_ID: field = 44556677889912field;
    const PROVISION_FACTOR: u128 = 125u128;
    const TREASURY : address = eclipse_lending_usda_vault_5.aleo;   
    const USDA_FEED_ID: field = 2field;
    const LLTV : u128 = 125u128;
    const ALEO_ID : field = 3443843282313283355522573239085696902919850365217539366784739393210722344986field;

    struct PositionMeta {
        coll_amt: u128,
        debt_amt: u128,
        price_liq: u128,
        max_debt: u128,
        t_last: u64
    }

    record Position {
        owner: address,
        id: u64
    }
    
    mapping liquidated_ids: u64 => bool;
    mapping metas: u64 => PositionMeta;
    mapping next_id: field => u64;

    inline is_owner(caller: address) {
        assert(caller == ADMIN);
    }


    // --------------------------------------------------------------------
    // 1 Initialisation (enregistre USDA)
    // --------------------------------------------------------------------
    async transition initialize(public caller: address) -> Future {
        is_owner(caller);
        let fut: Future = token_registry.aleo/register_token(
            USDA_TOKEN_ID,
            567137312326300096786987u128, // "USDA"
            1480805620u128,              
            18u8,
            1_000_000_000_000_000_000u128,
            false,
            ADMIN
        );
        return finalize_initialize(fut);
    }
    async function finalize_initialize(fut: Future) {
        fut.await();
        next_id.set(0field, 0u64);
    }

    // --------------------------------------------------------------------
    // 2 Dépôt de collatéral
    // --------------------------------------------------------------------
    async transition deposit(
        public amount: u64,
        public price: u128,
        public last_id : u64,
        private caller: address,
        private token_record: credits.aleo/credits
    ) -> (Position, credits.aleo/credits, Future) {
        let (token, fut):(credits.aleo/credits, Future)=credits.aleo/transfer_private_to_public(token_record, TREASURY, amount);

        let new_id: u64 = last_id + 1u64;

        let pos: Position = Position{
            owner: caller,
            id: new_id
        };

        return (pos, token, finalize_deposit(fut, new_id,amount,price,caller));
    }
    async function finalize_deposit(
        public fut: Future,
        public pos_id: u64,
        public amount: u64,
        public price:  u128,
        public caller: address
    ) {
        let current:u64 = next_id.get_or_use(USDA_TOKEN_ID, 0u64);
        assert(pos_id == current + 1u64);
        next_id.set(USDA_TOKEN_ID, current+1u64);

        fut.await();

        let coll_val: u128 = (amount as u128) * price;
        let price_liq: u128 = coll_val * LLTV / 100u128;
        let max_debt: u128 = coll_val * PROVISION_FACTOR / 100u128;

        metas.set(pos_id, PositionMeta{
            coll_amt: amount as u128,
            debt_amt: 0u128,
            price_liq: price_liq,
            max_debt: max_debt,
            t_last: block.height as u64
        });
    }


    // --------------------------------------------------------------------
    // 3 Mint de USDA
    // --------------------------------------------------------------------
    async transition mint(
        public usda_out: u128,
        public price: u128,
        private pos: Position,
    ) -> (Position, token_registry.aleo/Token, Future) {
        assert(pos.owner == self.caller);

        let (record_obtained, fut_mint): (token_registry.aleo/Token, Future) = token_registry.aleo/mint_private(USDA_TOKEN_ID, self.caller, usda_out, false, 0u32);
        return (pos, record_obtained, finalize_mint(fut_mint, pos.id, usda_out, price));
    }
    async function finalize_mint(
        fut_mint: Future,
        public pos_id: u64,
        public out: u128,
        public price: u128,
    ) {
        assert(out > 0u128);
        assert(price > 0u128);
        assert(liquidated_ids.get_or_use(pos_id, false) == false);

        let oracle_price: u128 = eclipse_oracle_aggregate_2.aleo/latest_price.get(USDA_FEED_ID);
        assert(price == oracle_price);

        fut_mint.await();

        let meta = metas.get(pos_id);
        let coll_val = meta.coll_amt * price;
        let new_debt = meta.debt_amt + out;
        let max_debt = coll_val * PROVISION_FACTOR / 100u128;
        assert(new_debt <= max_debt);
        let price_liq = coll_val * LLTV / 100u128;

        metas.set(pos_id, PositionMeta {
            coll_amt: meta.coll_amt,
            debt_amt: new_debt,
            price_liq: price_liq,
            max_debt: max_debt,
            t_last: block.height as u64
        });
    }


    // --------------------------------------------------------------------
    // 4 Remboursement (burn USDA)
    // --------------------------------------------------------------------
    async transition burn(
        public usda_in: u128,
        public price: u128,
        private pos: Position,
        private token: token_registry.aleo/Token
    ) -> (Position, token_registry.aleo/Token, Future) {
        assert(pos.owner == self.caller);
        let (token_obtained, fut_burn): (token_registry.aleo/Token, Future) = token_registry.aleo/burn_private(token, usda_in);
        return (pos, token_obtained, finalize_burn(fut_burn, pos.id, usda_in, price));
    }
    async function finalize_burn(
        fut_burn: Future,
        public pos_id: u64,
        public in_: u128,
        public price: u128,
    ) {
        assert(in_ > 0u128);
        assert(price > 0u128);
        assert(liquidated_ids.get_or_use(pos_id, false) == false);

        let oracle_price: u128 = eclipse_oracle_aggregate_2.aleo/latest_price.get(USDA_FEED_ID);
        assert(price == oracle_price);

        fut_burn.await();

        let meta = metas.get(pos_id);
        assert(meta.debt_amt >= in_);

        let new_debt = meta.debt_amt - in_;
        let coll_val = meta.coll_amt * price;
        let max_debt = coll_val * PROVISION_FACTOR / 100u128;
        let price_liq = coll_val * LLTV / 100u128;

        metas.set(pos_id, PositionMeta {
            coll_amt: meta.coll_amt,
            debt_amt: new_debt,
            price_liq: price_liq,
            max_debt: max_debt,
            t_last: block.height as u64
        });
    }


    // --------------------------------------------------------------------
    // 5 Récupération du collatéral
    // --------------------------------------------------------------------
    async transition withdraw(
        public pos: Position,
        public price: u128,
        public amount: u64
    ) -> (Position, credits.aleo/credits, Future) {
        assert(pos.owner == self.caller);

        let (token, fut):(credits.aleo/credits, Future) = credits.aleo/transfer_public_to_private(self.caller, amount);
        return (pos, token, finalize_withdraw(fut, pos.id, price, amount));
    }
   async function finalize_withdraw(
        fut: Future,
        public pos_id: u64,
        public price: u128,
        public amount: u64
   ) {
        let oracle_price: u128 = eclipse_oracle_aggregate_2.aleo/latest_price.get(USDA_FEED_ID);
        assert(price == oracle_price);

        fut.await();

        let meta = metas.get(pos_id);
        assert(!liquidated_ids.get_or_use(pos_id, false));
 
        let amt128: u128 = amount as u128;
        assert(amt128 <= meta.coll_amt);
        let remaining_coll: u128 = meta.coll_amt - amt128;

        let coll_val_rem = remaining_coll * price;
        let max_debt_rem = coll_val_rem * PROVISION_FACTOR / 100u128;
        assert(meta.debt_amt <= max_debt_rem);

        let price_liq_new = remaining_coll * LLTV / 100u128;
        metas.set(pos_id, PositionMeta {
            coll_amt: remaining_coll,
            debt_amt: meta.debt_amt,
            price_liq: price_liq_new,
            max_debt: max_debt_rem,
            t_last: block.height as u64
        });
    }



    // --------------------------------------------------------------------
    // 5 Liquidation permissionless
    // --------------------------------------------------------------------
    mapping liquidation_refund: u64 => u128;
    mapping liquidation_collateral: u64 => u128;

    // 5.1 : Liquidation de la position
    async transition liquidate(
        public id: u64,
        public price: u128,
        public usda_sent: u128,
        public debt_amt: u128,
        private record_token: token_registry.aleo/Token
    ) -> (token_registry.aleo/Token, Future) {
        let (token, fut_burn): (token_registry.aleo/Token, Future) = token_registry.aleo/burn_private(record_token, usda_sent);
        return (token, finalize_liquidate(fut_burn, id, usda_sent, price));
    }
    async function finalize_liquidate(
        fut_burn: Future,
        public id: u64,
        public usda_sent: u128,
        public price: u128
    ) {
        fut_burn.await();

        let oracle_price: u128 = eclipse_oracle_aggregate_2.aleo/latest_price.get(USDA_FEED_ID);
        assert(price == oracle_price);

        let meta: PositionMeta = metas.get(id);
        assert(price <= meta.price_liq);

        let refund: u128 = usda_sent > meta.debt_amt ? usda_sent - meta.debt_amt : 0u128;

        liquidation_refund.set(id, refund);
        liquidation_collateral.set(id, meta.coll_amt);

        metas.remove(id);
        liquidated_ids.set(id, true);
    }


    // 5.2 : Récupération des fonds engagés en surplus (pour les gens bêtes mdr)
    async transition claim_refund(
        public id: u64,
        public refund: u128
    ) -> (token_registry.aleo/Token, Future) {
        let (token, fut_mint): (token_registry.aleo/Token, Future) = token_registry.aleo/mint_private(USDA_TOKEN_ID, self.caller, refund, false, 0u32);
        return (token, finalize_claim_refund(fut_mint, id, refund));
    }
    async function finalize_claim_refund(
        fut_mint: Future,
        public id: u64,
        public refund: u128
    ) {
        fut_mint.await();
        let stored: u128 = liquidation_refund.get_or_use(id, 0u128);
        assert(refund == stored);
        liquidation_refund.remove(id);
    }


    // 5.3 : Récupération du collatéral
    async transition claim_collateral(
        public id: u64,
        public amount: u64
    ) -> (credits.aleo/credits, Future) {
        let (token, fut): (credits.aleo/credits, Future) = credits.aleo/transfer_public_to_private(self.caller, amount);
        return (token, finalize_claim_collateral(fut, id, amount));
    }

    async function finalize_claim_collateral(
        fut: Future,
        public id: u64,
        public amount: u64
    ) {
        fut.await();
        let stored: u128 = liquidation_collateral.get_or_use(id, 0u128);
        assert(amount as u128 == stored);
        liquidation_collateral.remove(id);
    }
}