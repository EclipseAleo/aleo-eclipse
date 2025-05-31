////////////////////////////////////////////////////////////////////////////////
// Eclipse Lending – Treasury 
//
// Author : **Florent Gaujal** <https://github.com/floflo777>
// Date   : 2025-05-30
//
// ### Purpose
// This program manages the treasury for Eclipse Lending, allowing users to stake and withdraw ECLP tokens, and claim fees in USDA tokens.


import token_registry.aleo;
import eclipse_lending_usda_vault_7.aleo;

program eclipse_lending_treasury.aleo {

    const ADMIN: address  = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;
    const USDA_TOKEN_ID: field = 44556677889915field;
    const ECLP_TOKEN_ID: field = 123field;

    mapping stakes: address => u128;
    mapping total_staked: field => u128;
    mapping paid_fees: address => u128;

    inline is_admin(caller: address) {
        assert(caller == ADMIN);
    }

    // ----------------------------------------
    // 1. Stake tokens
    // ----------------------------------------
    async transition stake(
        public amount: u128,
        public caller: address
    ) -> Future {
        let fut: Future = token_registry.aleo/transfer_public_as_signer(ECLP_TOKEN_ID,treasury.aleo,amount);
        return finalize_stake(fut, amount, caller);
    }

    async function finalize_stake(
        public fut: Future,
        public amount: u128,
        public caller: address
    ) {
        fut.await();
        assert(amount > 0u128);

        let prev: u128 = stakes.get_or_use(caller, 0u128);
        if (prev == 0u128) {
            let current_fees: u128 = eclipse_lending_usda_vault_7.aleo/total_fees.get_or_use(USDA_TOKEN_ID,0u128);
            paid_fees.set(caller, current_fees);
        }

        stakes.set(caller, prev + amount);
        let tot: u128 = total_staked.get_or_use(ECLP_TOKEN_ID, 0u128);
        total_staked.set(ECLP_TOKEN_ID, tot + amount);
    }


    // ----------------------------------------
    // 2. Withdraw tokens
    // ----------------------------------------
    async transition withdraw(
        public amount: u128,
        public caller: address
    ) -> Future {
        let fut: Future = token_registry.aleo/transfer_public(ECLP_TOKEN_ID,caller,amount);
        return finalize_withdraw(fut, amount, caller);
    }

    async function finalize_withdraw(
        public fut: Future,
        public amount: u128,
        public caller: address
    ) {
        fut.await();

        let prev: u128 = stakes.get_or_use(caller, 0u128);
        assert(prev >= amount);

        let new_stake: u128 = prev - amount;
        stakes.set(caller, new_stake);

        let tot: u128 = total_staked.get_or_use(ECLP_TOKEN_ID, 0u128);
        total_staked.set(ECLP_TOKEN_ID, tot - amount);

        let current_fees: u128 = eclipse_lending_usda_vault_7.aleo/total_fees.get_or_use(USDA_TOKEN_ID,0u128);
        paid_fees.set(caller, current_fees);
    }


    // ----------------------------------------
    // 3. Claim fees
    // ----------------------------------------
    async transition claim(
        public stake_amt: u128,  
        public total: u128,
        public last_paid: u128,
        public current_fees: u128 
    ) -> Future {
        let delta: u128 = current_fees - last_paid;
        assert(delta > 0u128);

        let payout: u128 = (delta * stake_amt) / total;
        assert(payout > 0u128);
        let fut:Future = credits.aleo/transfer_public(self.caller, payout as u64);
        return (finalize_claim(fut, stake_amt, total, last_paid, current_fees, self.caller));
    }

    async function finalize_claim(
        public fut: Future,
        public stake_amt: u128,
        public total: u128,
        public last_paid: u128,
        public current_fees: u128,
        public caller: address
    ) {
        fut.await();

        let s: u128 = stakes.get_or_use(caller, 0u128);
        let tot: u128 = total_staked.get_or_use(ECLP_TOKEN_ID, 0u128);
        let paid: u128 = paid_fees.get_or_use(caller, 0u128);
        let fees: u128 = eclipse_lending_usda_vault_7.aleo/total_fees.get_or_use(USDA_TOKEN_ID, 0u128);

        assert(s == stake_amt);
        assert(tot == total);
        assert(paid == last_paid);
        assert(fees == current_fees);
        paid_fees.set(caller, current_fees);
    }

}
