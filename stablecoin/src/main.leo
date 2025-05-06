import token_registry.aleo;
import credits.aleo;

program floflo_stablecoin_vault.aleo {
    const TOKEN_ID: field = 112233445566778899field;
    const NAME:    u128 = 128928039109u128; // "FLOFLO_DAI"
    const SYMBOL:  u128 = 19839283u128;     // "FLO"
    const DECIMALS: u8  = 18u8;
    const MAX_SUPPLY: u128 = 1_000_000_000u128;

    const collateral_ratio: u128 = 150u128;
    const ADMIN: address = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;
    const TREASURY: address = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;

    mapping collaterals: address =>  u128;
    mapping debts:address => u128;


    // Initialize
    async transition initialize() -> Future {
        let fut: Future = token_registry.aleo/register_token(
            TOKEN_ID,
            NAME,
            SYMBOL,
            DECIMALS,
            MAX_SUPPLY,
            false,
            ADMIN
        );
        return finalize_initialize(fut);
    }
    async function finalize_initialize(fut: Future) {
        fut.await();
    }



    // Deposit
    async transition deposit(public amount: u128) -> Future {
        assert(amount > 0u128);
        assert(amount <= 18_446_744_073_709_551_615u128);
        let amount_u64: u64 = amount as u64;
        let fut_transfer: Future = credits.aleo/transfer_public(self.address, amount_u64);
        return finalize_deposit(fut_transfer, self.caller, amount);
    }
    async function finalize_deposit(fut_transfer: Future, caller:address, amount:u128) {
        fut_transfer.await();
        let prev: u128 = collaterals.get_or_use(caller, 0u128);
        collaterals.set(caller, prev + amount);
    }



    // Mint
    async transition mint(public amount: u128) -> Future {
        assert(amount > 0u128);
        let fut_mint: Future = token_registry.aleo/mint_public(
            TOKEN_ID,
            self.caller,
            amount,
            0u32
        );
        return finalize_mint(fut_mint, self.caller, amount);
    }
    async function finalize_mint(
        fut:    Future,
        user:   address,
        amount: u128
    ) {
        fut.await();
        let collat: u128 = collaterals.get_or_use(user, 0u128);
        let debt:   u128 = debts.get_or_use(user, 0u128);
        assert(collat * 100u128 >= (debt + amount) * collateral_ratio);
        debts.set(user, debt + amount);
    }



    // Redeem and Burn
    async transition redeem(public amount: u128) -> Future {
        assert(amount > 0u128);
        let fut_burn: Future = token_registry.aleo/burn_public(
            TOKEN_ID,
            self.caller,
            amount
        );
        let returned_credits: u128 = amount * collateral_ratio / 100u128;
        assert(returned_credits <= 18_446_744_073_709_551_615u128);
        let returned_u64: u64 = returned_credits as u64;
        let fut_transfer: Future = credits.aleo/transfer_public(
            self.caller,
            returned_u64
        );
        return finalize_redeem(
            fut_burn,
            fut_transfer,
            self.caller,
            amount,
            returned_credits
        );
    }
    async function finalize_redeem(
        fut_burn:        Future,
        fut_transfer:    Future,
        user:            address,
        burned_amount:   u128,
        returned_amount: u128
    ) {
        fut_burn.await();
        fut_transfer.await();
        let debt:   u128 = debts.get_or_use(user, 0u128);
        let collat: u128 = collaterals.get_or_use(user, 0u128);
        assert(debt >= burned_amount);
        assert(collat >= returned_amount);
        debts.set(user, debt   - burned_amount);
        collaterals.set(user, collat - returned_amount);
    }

    

}
