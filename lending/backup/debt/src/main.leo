// File: zk_debt_note.aleo
// Un “NFT” 100% privé pour représenter une dette.
// Mintée par la paire, transférable, burnée au repay.

import token_registry.aleo;

program eclipse_lending_debt_note.aleo {
    // --------------------------------------------------------------------
    // Constantes (à ajuster selon votre déploiement)
    // --------------------------------------------------------------------
    const PAIR_CONTRACT: address = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;
    const USDA_TOKEN_ID: field   = 445566778899field;
    const ADMIN:          address = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;

    // --------------------------------------------------------------------
    // Mappings scalaires (pas de record)
    // --------------------------------------------------------------------
    mapping note_owner:     u64   => address;  // id → détenteur
    mapping note_principal: u64   => u128;     // id → montant emprunté
    mapping note_rate:      u64   => u64;      // id → taux appliqué
    mapping next_note_id:   field => u64;      // compteur d’IDs

    // ====================================================================
    // 1. mint_from_pair — création d’une nouvelle note
    // ====================================================================
    async transition mint_from_pair(
        public to:     address,
        public amount: u128,
        public rate:   u64
    ) -> Future {
        assert(self.caller == PAIR_CONTRACT);
        assert(amount > 0u128);

        // Dummy Future pour respecter le pattern sans mapping ici
        let f_dummy: Future = token_registry.aleo/mint_public(
            USDA_TOKEN_ID,
            ADMIN,
            0u128,
            0u32
        );
        return finalize_mint_from_pair(f_dummy, to, amount, rate);
    }

    async function finalize_mint_from_pair(
        f_dummy:       Future,
        public to:     address,
        public amount: u128,
        public rate:   u64
    ) {
        f_dummy.await();

        let counter_key: field = 0field;
        let id_now: u64 = next_note_id.get_or_use(counter_key, 0u64);
        next_note_id.set(counter_key, id_now + 1u64);

        note_owner.set(id_now, to);
        note_principal.set(id_now, amount);
        note_rate.set(id_now, rate);
    }

    // ====================================================================
    // 2. transfer_note — cession de la note à un nouveau propriétaire
    // ====================================================================
    async transition transfer_note(
        public id:        u64,
        public new_owner: address
    ) -> Future {
        // Dummy Future pour pattern
        let f_dummy: Future = token_registry.aleo/mint_public(
            USDA_TOKEN_ID,
            ADMIN,
            0u128,
            0u32
        );
        return finalize_transfer_note(f_dummy, id, new_owner, self.caller);
    }

    async function finalize_transfer_note(
        f_dummy:      Future,
        public id:    u64,
        public new_owner: address,
        public caller:    address
    ) {
        f_dummy.await();

        let owner: address = note_owner.get(id);
        assert(caller == owner);

        note_owner.set(id, new_owner);
    }

    // ====================================================================
    // 3. burn_on_repay — suppression de la note après remboursement
    // ====================================================================
    async transition burn_on_repay(
        public id: u64
    ) -> Future {
        let f_dummy: Future = token_registry.aleo/burn_public(
            USDA_TOKEN_ID,
            self.caller,
            0u128
        );
        return finalize_burn_on_repay(f_dummy, id, self.caller);
    }

    async function finalize_burn_on_repay(
        f_dummy: Future,
        public id:     u64,
        public caller: address
    ) {
        f_dummy.await();

        let owner: address = note_owner.get(id);
        assert(caller == owner);

        note_owner.remove(id);
        note_principal.remove(id);
        note_rate.remove(id);
    }
}
