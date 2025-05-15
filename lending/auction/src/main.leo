import token_registry.aleo;

program eclipse_lending_auction.aleo {

    const USDA_TOKEN_ID: field = 445566778899field;
    const FACTOR_START: u128 = 105u128;
    const FACTOR_END: u128 = 80u128;
    const DURATION: u32 = 64000u32;

    struct Auction {
        victim: address,
        collateral_id: field,
        collateral_amt: u128,
        debt_usda: u128,
        start_block: u32,
        active: bool
    }

    mapping auctions: u64 => Auction;
    mapping next_id: field => u64;

    async transition start_auction(
        public victim: address,
        public collateral_id: field,
        public collateral_amt: u128,
        public debt_usda: u128,
        public caller: address
    ) -> Future {
        assert(self.caller == zk_usda_vault.aleo);
        return finalize_start(victim, collateral_id, collateral_amt, debt_usda);
    }

    async function finalize_start(
        public victim: address,
        public collateral_id: field,
        public collateral_amt: u128,
        public debt_usda: u128
    ) {
        assert(collateral_amt > 0u128);
        assert(debt_usda > 0u128);

        let counter_key: field = 0field;
        let id_now: u64 = next_id.get_or_use(counter_key, 0u64);
        next_id.set(counter_key, id_now + 1u64);

        let auc: Auction = Auction{
            victim: victim,
            collateral_id: collateral_id,
            collateral_amt: collateral_amt,
            debt_usda: debt_usda,
            start_block: block.height,
            active: true
        };
        auctions.set(id_now, auc);
    }

    async transition take(
        public auction_id: u64,
        public collateral_id_in: field,
        public collateral_amt_in: u128,
        public debt_usda_in: u128,
        public payment: u128,
        public caller: address
    ) -> Future {
        let fut_burn: Future = token_registry.aleo/burn_public(
            USDA_TOKEN_ID,
            caller,
            payment
        );
        let fut_collat: Future = token_registry.aleo/transfer_public(
            collateral_id_in,
            caller,
            collateral_amt_in
        );
        return finalize_take(
            fut_burn,
            fut_collat,
            auction_id,
            collateral_id_in,
            collateral_amt_in,
            debt_usda_in,
            payment
        );
    }

    async function finalize_take(
        fut_burn: Future,
        fut_collat: Future,
        public auction_id: u64,
        public collateral_id_in: field,
        public collateral_amt_in: u128,
        public debt_usda_in: u128,
        public payment: u128
    ) {
        let auc: Auction = auctions.get(auction_id);
        assert(auc.active);
        assert(auc.collateral_id == collateral_id_in);
        assert(auc.collateral_amt == collateral_amt_in);
        assert(auc.debt_usda == debt_usda_in);

        let elapsed: u32 = block.height - auc.start_block;
        let span: u128 = FACTOR_START - FACTOR_END;
        let prog: u128 = (span * (elapsed as u128)) / (DURATION as u128);
        let factor: u128 = (elapsed >= DURATION) ? FACTOR_END : FACTOR_START - prog;

        let expected: u128 = auc.debt_usda * factor / 100u128;
        assert(payment == expected);

        let closed: Auction = Auction{
            victim: auc.victim,
            collateral_id: auc.collateral_id,
            collateral_amt: auc.collateral_amt,
            debt_usda: auc.debt_usda,
            start_block: auc.start_block,
            active: false
        };
        auctions.set(auction_id, closed);

        fut_burn.await();
        fut_collat.await();
    }
}
