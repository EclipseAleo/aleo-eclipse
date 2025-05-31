// File: eclipse_governance_token.aleo
// Token de gouvernance privé + vote-escrow (veGOV)

import token_registry.aleo;

program eclipse_governance_token.aleo {
    // --------------------------------------------------------------------
    // Constantes
    // --------------------------------------------------------------------
    const ADMIN:         address = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;
    const GOV_TOKEN_ID:  field   = 444455556666field;     // Identifiant du token de gouvernance
    const NAME:          u128    = 1099511627776u128;     // "MGOV" en bytes-32
    const SYMBOL:        u128    = 1298074214633706907132624082305024u128; // "MGOV"
    const DECIMALS:      u8      = 18u8;
    const MAX_SUPPLY:    u128    = 1_000_000_000u128;     // Supply max
    const MAX_LOCK:      u64     = 31_536_000u64;         // Durée max de lock ≈ 1 an

    // --------------------------------------------------------------------
    // Storage
    // --------------------------------------------------------------------
    mapping total_supply: field   => u128;    // total minted so far
    mapping is_minter:    address => bool;    // qui peut mint
    mapping stake_amount: address => u128;    // montant de MGOV staké
    mapping lock_until:   address => u64;     // bloc de fin de lock
    mapping ve_balance:   address => u128;    // veMGOV (poids de vote)

    // --------------------------------------------------------------------
    // 1. Initialisation (une seule fois)
    // --------------------------------------------------------------------
    async transition initialize(
        public caller: address
    ) -> Future {
        assert(caller == ADMIN);
        let f: Future = token_registry.aleo/register_token(
            GOV_TOKEN_ID,
            NAME,
            SYMBOL,
            DECIMALS,
            MAX_SUPPLY,
            false,      // pas d’authorization externe
            ADMIN       // party
        );
        return finalize_initialize(f);
    }

    async function finalize_initialize(
        f: Future
    ) {
        f.await();
        // Initialise le compteur de supply
        total_supply.set(GOV_TOKEN_ID, 0u128);
    }

    // --------------------------------------------------------------------
    // 2. Grant / Revoke du droit de mint (ADMIN only)
    // --------------------------------------------------------------------
    async transition grant_minter(
        public caller: address,
        public minter: address
    ) -> Future {
        assert(caller == ADMIN);
        // dummy future pour respecter pattern
        let f: Future = token_registry.aleo/mint_public(
            GOV_TOKEN_ID, ADMIN, 0u128, 0u32
        );
        return finalize_grant_minter(f, minter);
    }

    async function finalize_grant_minter(
        f: Future,
        public minter: address
    ) {
        f.await();
        is_minter.set(minter, true);
    }

    async transition revoke_minter(
        public caller: address,
        public minter: address
    ) -> Future {
        assert(caller == ADMIN);
        let f: Future = token_registry.aleo/mint_public(
            GOV_TOKEN_ID, ADMIN, 0u128, 0u32
        );
        return finalize_revoke_minter(f, minter);
    }

    async function finalize_revoke_minter(
        f: Future,
        public minter: address
    ) {
        f.await();
        is_minter.set(minter, false);
    }

    // --------------------------------------------------------------------
    // 3. Mint de récompenses (minters only)
    // --------------------------------------------------------------------
    async transition mint_reward(
        public caller: address,
        public to:     address,
        public amount: u128
    ) -> Future {
        // On fait directement le mint public
        let f: Future = token_registry.aleo/mint_public(
            GOV_TOKEN_ID, to, amount, 0u32
        );
        // Passe caller et amount à la finalisation
        return finalize_mint_reward(f, caller, amount);
    }


    async function finalize_mint_reward(
        f: Future,
        public caller: address,
        public amount: u128
    ) {
        f.await();
        // Vérifie le droit de minter (mapping autorisé ici)
        assert(is_minter.get_or_use(caller, false));

        // Met à jour le total_supply
        let prev: u128 = total_supply.get_or_use(GOV_TOKEN_ID, 0u128);
        total_supply.set(GOV_TOKEN_ID, prev + amount);
    }

    // --------------------------------------------------------------------
    // 4. Stake (lock MGOV → mint veMGOV)
    // --------------------------------------------------------------------
    async transition stake(
        public caller:        address,
        public amount:        u128,
        public lock_duration: u64
    ) -> Future {
        assert(amount > 0u128);
        assert(lock_duration <= MAX_LOCK);
        // Transfert public→privé
        let (rec, f): (token_registry.aleo/Token, Future) =
            token_registry.aleo/transfer_public_to_private(
                GOV_TOKEN_ID, caller, amount, false
            );
        return finalize_stake(f, caller, amount, lock_duration);
    }

    async function finalize_stake(
        f: Future,
        public caller:        address,
        public amount:        u128,
        public lock_duration: u64
    ) {
        f.await();
        // Aucun stake en cours
        let prev: u128 = stake_amount.get_or_use(caller, 0u128);
        assert(prev == 0u128);

        let now:   u64 = block.height as u64;
        let until: u64 = now + lock_duration;
        stake_amount.set(caller, amount);
        lock_until.set(caller,   until);

        // veMGOV = amount * (lock_duration / MAX_LOCK)
        let ve_amt: u128 = amount * (lock_duration as u128) / (MAX_LOCK as u128);
        ve_balance.set(caller, ve_amt);
    }

    // --------------------------------------------------------------------
    // 5. Withdraw stake (après lock) → burn veMGOV
    // --------------------------------------------------------------------
    async transition withdraw_stake(
        public caller:    address,
        public stake_amt: u128
    ) -> Future {
        // Transfert privé→public du principal
        let f: Future = token_registry.aleo/transfer_public(
            GOV_TOKEN_ID, caller, stake_amt
        );
        return finalize_withdraw_stake(f, caller, stake_amt);
    }

    async function finalize_withdraw_stake(
        f: Future,
        public caller:    address,
        public stake_amt: u128
    ) {
        f.await();
        // Vérifie les conditions
        let stored: u128 = stake_amount.get_or_use(caller, 0u128);
        let until:  u64 = lock_until.get_or_use(caller, 0u64);
        assert(stored == stake_amt);
        assert(block.height as u64 >= until);

        // Reset mappings
        stake_amount.set(caller, 0u128);
        lock_until.set(caller,   0u64);
        ve_balance.set(caller,   0u128);
    }
}
