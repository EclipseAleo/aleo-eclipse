// File: eclipse_governance.aleo
// Gouvernance on-chain privée pour le protocole de lending

import token_registry.aleo;

program eclipse_governance.aleo {
    // --------------------------------------------------------------------
    // Constants
    // --------------------------------------------------------------------
    const GOVERNANCE_TOKEN_ID:  field = 444455556666field;  // ajustez si besoin
    const VOTING_PERIOD_BLOCKS: u64   = 120_000u64;         // ≈ 1 mois (~28s/block)
    const QUORUM_VOTES:         u128  = 1_000u128;          // seuil minimal de votes

    // --------------------------------------------------------------------
    // Types
    // --------------------------------------------------------------------
    struct Proposal {
        proposer:      address,
        target:        address,
        call_data:     field,
        prop_value:         u128,
        start_block:   u64,
        end_block:     u64,
        for_votes:     u128,
        against_votes: u128,
        executed:      bool
    }

    // --------------------------------------------------------------------
    // Storage
    // --------------------------------------------------------------------
    mapping proposal_count: field => u64;      // compteur d’IDs
    mapping proposals:      u64   => Proposal; // Proposals par ID
    mapping has_voted:      field => bool;     // clé = vote_key(pid, voter)

    // --------------------------------------------------------------------
    // Inline Helpers
    // --------------------------------------------------------------------
    inline to_field_u64(x: u64) -> field {
        return x as field;
    }

    inline vote_key(pid: u64, voter: address) -> field {
        return to_field_u64(pid) + (voter as field);
    }

    // ====================================================================
    // 1. Proposer une nouvelle action
    // ====================================================================
    async transition propose(
        public target:      address,
        public call_data:   field,
        public prop_value:       u128,
        public description: field      // hash hors-chaîne
    ) -> Future {
        return finalize_propose(self.caller, target, call_data, prop_value, description);
    }

    async function finalize_propose(
        public proposer:   address,
        public target:      address,
        public call_data:   field,
        public prop_value:       u128,
        public description: field
    ) {
        // 1) Génère un nouvel ID
        let key: field = 0field;
        let pid: u64   = proposal_count.get_or_use(key, 0u64);
        proposal_count.set(key, pid + 1u64);

        // 2) Calcule la période de vote
        let start: u64 = block.height as u64;
        let end:   u64 = start + VOTING_PERIOD_BLOCKS;

        // 3) Stocke la proposition
        let p: Proposal = Proposal {
            proposer:      proposer,
            target:        target,
            call_data:     call_data,
            prop_value:         prop_value,
            start_block:   start,
            end_block:     end,
            for_votes:     0u128,
            against_votes: 0u128,
            executed:      false
        };
        proposals.set(pid, p);
    }

    // ====================================================================
    // 2. Voter sur une proposition
    // ====================================================================
    async transition vote(
        public proposal_id: u64,
        public support:     bool
    ) -> Future {
        return finalize_vote(self.caller, proposal_id, support);
    }

    async function finalize_vote(
        public voter:       address,
        public proposal_id: u64,
        public support:     bool
    ) {
        // 1) Récupère la proposition
        let old: Proposal = proposals.get(proposal_id);

        // 2) Vérifie la période de vote
        let now_blk: u64 = block.height as u64;
        assert(now_blk >= old.start_block && now_blk <= old.end_block);

        // 3) Empêche le double-vote
        let vkey: field = vote_key(proposal_id, voter);
        assert(!has_voted.get_or_use(vkey, false));

        // 4) Poids de vote pour POC (1 voix)
        let votes: u128 = 1u128;

        // 5) Calcule les nouveaux totaux avec un ternaire
        let new_for:     u128 = support ? (old.for_votes + votes)      : old.for_votes;
        let new_against: u128 = support ? old.against_votes              : (old.against_votes + votes);

        // 6) Met à jour la proposition
        let updated: Proposal = Proposal {
            proposer:      old.proposer,
            target:        old.target,
            call_data:     old.call_data,
            prop_value:         old.prop_value,
            start_block:   old.start_block,
            end_block:     old.end_block,
            for_votes:     new_for,
            against_votes: new_against,
            executed:      old.executed
        };
        proposals.set(proposal_id, updated);

        // 7) Marque comme voté
        has_voted.set(vkey, true);
    }

    // ====================================================================
    // 3. Exécuter une proposition validée
    // ====================================================================
    async transition execute(
        public proposal_id: u64
    ) -> Future {
        return finalize_execute(self.caller, proposal_id);
    }

    async function finalize_execute(
        public executor:     address,
        public proposal_id: u64
    ) {
        let old: Proposal = proposals.get(proposal_id);

        // a) Fin de vote & non exécutée
        let now_blk: u64 = block.height as u64;
        assert(now_blk > old.end_block && !old.executed);

        // b) Quorum & majorité
        let total: u128 = old.for_votes + old.against_votes;
        assert(total >= QUORUM_VOTES && old.for_votes > old.against_votes);

        // c) Marque comme exécutée
        let updated: Proposal = Proposal {
            proposer:      old.proposer,
            target:        old.target,
            call_data:     old.call_data,
            prop_value:         old.prop_value,
            start_block:   old.start_block,
            end_block:     old.end_block,
            for_votes:     old.for_votes,
            against_votes: old.against_votes,
            executed:      true
        };
        proposals.set(proposal_id, updated);

        // d) L’exécution (target.call…) se fera hors-chaîne
    }
}
