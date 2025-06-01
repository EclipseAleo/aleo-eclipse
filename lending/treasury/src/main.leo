////////////////////////////////////////////////////////////////////////////////
// Eclipse Lending – Treasury 
//
// Author : **Florent Gaujal** <https://github.com/floflo777>
// Date   : 2025-05-30
//
// ### Purpose
// This program manages the treasury for Eclipse Lending, allowing users to stake and withdraw ECLP tokens, and claim fees in USDA tokens.


import token_registry.aleo;
import eclipse_lending_usda_vault_11.aleo;

program eclipse_lending_treasury_3.aleo {

    const ADMIN: address  = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;
    const ECLP_TOKEN_ID: field = 1234567898field;
    const USDA_TOKEN_ID: field = 44556677889917field;
    const TREASURY: address = eclipse_lending_treasury_3.aleo;

    mapping total_staked: field => u128;

    inline is_admin(caller: address) {
        assert(caller == ADMIN);
    }

    record stake_position {
        owner: address,
        amount: u128,
        height: u32,
        total_fees: u128
    }

    // ----------------------------------------
    // 1. Stake tokens
    // ----------------------------------------
    async transition stake(
        private amount: u128,
        private caller: address,
        private token_input: token_registry.aleo/Token,
        public fees_tot: u128,
        public actual_block: u32
    ) -> (token_registry.aleo/Token, stake_position, Future) {
        let (token, fut):(token_registry.aleo/Token, Future) = token_registry.aleo/transfer_private_to_public(TREASURY, amount, token_input);
        assert(token.token_id == ECLP_TOKEN_ID);
        let stake_pos: stake_position = stake_position {
            owner: caller,
            amount: amount,
            height: actual_block,
            total_fees: fees_tot
        };
        assert(token_input.amount >= amount);
        return (token, stake_pos, finalize_stake(fut, amount, caller, fees_tot, actual_block));
    }

    async function finalize_stake(
        public fut: Future,
        public amount: u128,
        public caller: address,
        public fees_tot: u128,
        public actual_block: u32
    ) {
        fut.await();
        let tot_fees:u128=eclipse_lending_usda_vault_11.aleo/cumulated_fees.get_or_use(USDA_TOKEN_ID, 0u128);
        assert_eq(tot_fees, fees_tot);
        assert(amount > 0u128);
        // POC purposes, should be removed in production
        assert(block.height <= actual_block + 60u32);
        assert(block.height >= actual_block);
        total_staked.set(ECLP_TOKEN_ID, total_staked.get_or_use(ECLP_TOKEN_ID, 0u128) + amount);
    }


    // ----------------------------------------
    // 2. Withdraw tokens
    // ----------------------------------------
    async transition withdraw(
        private amount: u128,
        private caller: address,
        private stake_pos: stake_position,
        public actual_block: u32,
        public fees_tot: u128
    ) -> (token_registry.aleo/Token, stake_position, Future) {
        let new_stake_pos: stake_position = stake_position {
            owner: stake_pos.owner,
            amount: stake_pos.amount - amount,
            height: actual_block,
            total_fees: fees_tot
        };
        assert(amount <= stake_pos.amount);
        let (token, fut): (token_registry.aleo/Token, Future) = token_registry.aleo/transfer_public_to_private(ECLP_TOKEN_ID,caller,amount, false);
        return (token, new_stake_pos, finalize_withdraw(fut, amount, caller, actual_block, fees_tot));
    }

    async function finalize_withdraw(
        public fut: Future,
        public amount: u128,
        public caller: address,
        public actual_block: u32,
        public fees_tot: u128
    ) {
        fut.await();
        // POC purposes, should be removed in production
        assert(block.height <= actual_block + 60u32);
        assert(block.height >= actual_block);
        assert(amount > 0u128);
        let tot_fees: u128 = eclipse_lending_usda_vault_11.aleo/cumulated_fees.get_or_use(USDA_TOKEN_ID, 0u128);
        assert_eq(tot_fees, fees_tot);
        total_staked.set(ECLP_TOKEN_ID, total_staked.get_or_use(ECLP_TOKEN_ID, 0u128) - amount);
    }



    // ----------------------------------------
    // 3. Claim fees
    // ----------------------------------------
    async transition claim(
        private position: stake_position,
        private caller: address,
        public actual_block: u32,
        public current_fees: u128,
        public tot_staked: u128
    ) -> (stake_position,credits.aleo/credits, Future) {
        let new_stake_pos: stake_position = stake_position {
            owner: position.owner,
            amount: position.amount,
            height: actual_block,
            total_fees: current_fees
        };
        let claimable_fees: u128 = (current_fees- position.total_fees)* position.amount / tot_staked;
        let (token, fut):(credits.aleo/credits, Future) = credits.aleo/transfer_public_to_private(caller, claimable_fees as u64);
        return (new_stake_pos, token, finalize_claim(fut, actual_block, current_fees, tot_staked));
    }

    async function finalize_claim(
        public fut: Future,
        public actual_block: u32,
        public current_fees: u128,
        public tot_staked: u128
    ) {
        fut.await();
        // POC purposes, should be removed in production
        assert(block.height <= actual_block + 60u32);
        assert(block.height >= actual_block);
        let tot_fees: u128 = eclipse_lending_usda_vault_11.aleo/cumulated_fees.get_or_use(USDA_TOKEN_ID, 0u128);
        assert_eq(tot_fees, current_fees);
        assert_eq(total_staked.get_or_use(ECLP_TOKEN_ID, 0u128), tot_staked);
        
    }
}
