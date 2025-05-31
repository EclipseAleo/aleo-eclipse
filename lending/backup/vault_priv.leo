import token_registry.aleo;
import eclipse_oracle_aggregate_4.aleo;
import proof_open.aleo;
import proof_liquidate.aleo;

program eclipse_lending_usda_vault.aleo {
    const ADMIN:            address = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;
    const USDA_TOKEN_ID:    field   = 445566778899field;
    const STALE_THRESHOLD:  u64     = 2880u64;
    const PROVISION_FACTOR: u128    = 125u128; 

    struct CollateralParam {
        feed_id: field,
        ltv_min: u128,
        lltv:    u128, 
        paused:  bool
    }
    mapping allowed: field => CollateralParam;
    mapping priv_commit: u64 => field;

    struct PositionMeta {
        price_liq:    u128,
        max_debt_cap: u128,
        t_last:       u64,
        challenged:   bool
    }

    mapping metas:   u64 => PositionMeta;
    mapping next_id: field => u64;

    record deposit_collat {
        amount: u128
    }


    // --------------------------------------------------------------------
    // 1. Calcul des intérêts
    // --------------------------------------------------------------------

    inline calculate_interest(
        rate_per_block: u128,
        delta_blocks:   u64
    ) -> u128 {
        return rate_per_block * (delta_blocks as u128)
             / 1_000_000_000_000_000_000u128;
    }

    inline check_admin(caller: address) {
        assert(caller == ADMIN);
    }


    // --------------------------------------------------------------------
    // 2. Initialisation du contrat
    // --------------------------------------------------------------------
    async transition initialize(
        public caller: address
    ) -> Future {
        check_admin(caller);
        let future_reg: Future = token_registry.aleo/register_token(
            USDA_TOKEN_ID,
            567137312326300096786987u128, // "USDA"
            1480805620u128,               // symbol
            18u8,
            1_000_000_000_000000000u128,
            false,
            ADMIN
        );
        return finalize_initialize(future_reg);
    }
    async function finalize_initialize(
        future_reg: Future
    ) {
        future_reg.await();
        next_id.set(0field, 0u64);
    }


    // --------------------------------------------------------------------
    // 3. Enregistrement des collatéraux autorisés
    // --------------------------------------------------------------------
    async transition deposit(
        public tokenId: field,
        public amount:  u128,
        public P_market:u128
    ) -> Future {
        let (tok, futureMove): (token_registry.aleo/Token, Future) =
            token_registry.aleo/transfer_public_to_private(
                tokenId,
                self.caller,
                amount,
                false
            );
        return finalize_deposit(futureMove, tokenId, amount, P_market);
    }
    async function finalize_deposit(
        futureMove:    Future,
        public tokenId: field,
        public amount:  u128,
        public P_market:u128
    ) {
        futureMove.await();
        let id: u64 = next_id.get_or_use(tokenId, 0u64);
        if id == 0u64 {
            next_id.set(tokenId, 1u64);
        }
        let commitment: field = Poseidon4::hash_to_field([
            amount    as field,
            0field,
            0field,
            0field
        ]);
        priv_commit.set(id, commitment);

        let cfg: CollateralParam = allowed.get(tokenId);
        let price:   u128 = eclipse_oracle_aggregate_4.aleo/latest_price.get(cfg.feed_id);
        let coll_val: u128 = amount * price;
        let price_liq:    u128 = coll_val * cfg.lltv / 100u128;
        let max_debt_cap: u128 = coll_val * PROVISION_FACTOR / 100u128;

        metas.set(id, PositionMeta{
            price_liq:    price_liq,
            max_debt_cap: max_debt_cap,
            t_last:       block.height as u64,
            challenged:   false
        });
    }



    // --------------------------------------------------------------------
    // 4. Minting and burning USDA
    // --------------------------------------------------------------------
    async transition mint(
        public tokenId: field,
        public usdaOut: u128,
        public P_market: u128
    ) -> Future {
        let futureMint: Future =
            token_registry.aleo/mint_public(
                USDA_TOKEN_ID,
                self.caller,
                usdaOut,
                0u32
            );
        return finalize_mint(futureMint, tokenId, usdaOut, P_market);
    }

    async function finalize_mint(
        futureMint:     Future,
        public tokenId: field,
        public usdaOut: u128,
        public P_market: u128
    ) {
        futureMint.await();

        let id: u64 = next_id.get_or_use(tokenId, 0u64);
        assert(id != 0u64);

        let newCommit: field = Poseidon4::hash_to_field([
            0field,        
            usdaOut as field,    
            0field,              
            0field               
        ]);
        priv_commit.set(id, newCommit);

        let cfg: CollateralParam = allowed.get(tokenId);
        let price_liq:    u128 = 0u128;
        let max_debt_cap: u128 = usdaOut * PROVISION_FACTOR / 100u128;

        metas.set(id, PositionMeta{
            price_liq:    price_liq,
            max_debt_cap: max_debt_cap,
            t_last:       block.height as u64,
            challenged:   false
        });
    }



    // --------------------------------------------------------------------
    // 5. Burning USDA
    // --------------------------------------------------------------------
    async transition burn(
        public tokenId:   field,
        public usdaIn:    u128,
        public P_market:  u128
    ) -> Future {
        let futureBurn: Future =
            token_registry.aleo/burn_public(
                USDA_TOKEN_ID,
                self.caller,
                usdaIn
            );
        return finalize_burn(futureBurn, tokenId, usdaIn, P_market);
    }

    async function finalize_burn(
        futureBurn:      Future,
        public tokenId:  field,
        public usdaIn:   u128,
        public P_market: u128
    ) {
        futureBurn.await();

        let id: u64 = next_id.get_or_use(tokenId, 0u64);
        assert(id != 0u64);

        let newCommit: field = Poseidon4::hash_to_field([
            0field,             
            usdaIn as field,    
            0field,           
            0field              
        ]);
        priv_commit.set(id, newCommit);

        let cfg: CollateralParam = allowed.get(tokenId);
        let price_liq:    u128 = 0u128;  
        let max_debt_cap: u128 = usdaIn * PROVISION_FACTOR / 100u128;

        metas.set(id, PositionMeta{
            price_liq:    price_liq,
            max_debt_cap: max_debt_cap,
            t_last:       block.height as u64,
            challenged:   false
        });
    }


    // --------------------------------------------------------------------
    // 6. Challenge liquidation
    // --------------------------------------------------------------------
    async transition challenge(
        public id:       u64,
        public P_market: u128
    ) -> Future {
        let futureBond: Future = token_registry.aleo/mint_public(
            USDA_TOKEN_ID,
            self.caller,
            1u128,
            0u32
        );
        return finalize_challenge(futureBond, id, P_market);
    }
    async function finalize_challenge(
        futureBond:   Future,
        public id:    u64,
        public P_market: u128
    ) {
        futureBond.await();

        let meta: PositionMeta = metas.get(id);
        assert(!meta.challenged);
        assert(
            block.height as u64 > meta.t_last + STALE_THRESHOLD
            || P_market <= meta.price_liq
        );

        metas.set(
            id,
            PositionMeta{
                price_liq:    meta.price_liq,
                max_debt_cap: meta.max_debt_cap,
                t_last:       meta.t_last,
                challenged:   true
            }
        );
    }



    // --------------------------------------------------------------------
    // 7. Liquidation
    // --------------------------------------------------------------------
    mapping liquidation_refund:     u64 => u128;
    mapping liquidation_collateral: u64 => u128;

    async transition liquidate(
        public token_id:    field,  
        public id:          u64,    
        public coll_amt:    u128,   
        public debt_amt:    u128,   
        public salt:        field,  
        public nonce:       field,  
        public usda_sent:   u128,  
        public max_debt_cap: u128   
    ) -> Future {
        proof_liquidate.aleo/prove_liquidate(
            max_debt_cap,
            debt_amt
        );

        let future_burn: Future = token_registry.aleo/burn_public(
            USDA_TOKEN_ID,
            self.caller,
            debt_amt
        );

        return finalize_liquidate(
            future_burn,
            token_id,
            id,
            coll_amt,
            debt_amt,
            salt,
            nonce,
            usda_sent,
            max_debt_cap
        );
    }
    async function finalize_liquidate(
        future_burn:     Future,
        public token_id: field,
        public id:       u64,
        public coll_amt: u128,
        public debt_amt: u128,
        public salt:     field,
        public nonce:    field,
        public usda_sent:u128,
        public max_debt_cap: u128
    ) {
        future_burn.await();

        let meta = Mapping::get(metas, id);
        assert(meta.max_debt_cap == max_debt_cap);

        let stored: field = Mapping::get_or_use(priv_commit, id, 0field);
        let opened: field = Poseidon4::hash_to_field([
            coll_amt as field,
            debt_amt as field,
            salt,
            nonce
        ]);
        assert(stored == opened);

        let refund: u128 = usda_sent > debt_amt ? usda_sent - debt_amt : 0u128;

        Mapping::set(liquidation_refund,     id, refund);
        Mapping::set(liquidation_collateral, id, coll_amt);

        Mapping::remove(priv_commit, id);
        Mapping::remove(metas,       id);
    }



    // --------------------------------------------------------------------
    // 8. Claim liquidation refund and collateral
    // --------------------------------------------------------------------
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


    // --------------------------------------------------------------------
    // Claim collateral after liquidation
    // --------------------------------------------------------------------
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
