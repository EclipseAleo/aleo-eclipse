// Eclipse Lending – Generic TOKEN / USDA pair
//
// Author : Florent Gaujal
// Date   : 2025-05-21

import token_registry.aleo;
import eclipse_lending_usda_vault.aleo;

program eclipse_lending_pair_template.aleo {

    // ─────────────────────────────────────────────────────────────────────
    // Constantes globales (à remplacer pour chaque clone)
    // ─────────────────────────────────────────────────────────────────────
    const ADMIN:    address = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;
    const TOKEN_ID: field   = 999999999999field;   // Collatéral
    const USDA_ID:  field   = 445566778899field;   // Dette

    const Q64:      u128    = 18446744073709551616u128;  // 2^64
    const UTIL_OPT: u128    = 80u128  * Q64 / 100u128;
    const R_BASE:   u128    = 2u128   * Q64 / 100u128;
    const R_SLOPE1: u128    = 6u128   * Q64 / 100u128;
    const R_SLOPE2: u128    = 90u128  * Q64 / 100u128;

    // ─────────────────────────────────────────────────────────────────────
    // Stockage d’état
    // ─────────────────────────────────────────────────────────────────────
    mapping total_supply:     field   => u128;
    mapping total_borrow:     field   => u128;
    mapping idx_supply:       field   => u128;
    mapping idx_borrow:       field   => u128;
    mapping last_block:       field   => u32;

    mapping principal_supply: address => u128;
    mapping snapshot_supply:  address => u128;
    mapping principal_borrow: address => u128;
    mapping snapshot_borrow:  address => u128;

    // ─────────────────────────────────────────────────────────────────────
    // 1. Initialise (one-shot)
    // ─────────────────────────────────────────────────────────────────────
    async transition initialise(public caller: address) -> Future {
        assert(caller == ADMIN);
        // TODO : vérifier index vierges, initialiser à Q64 et block.height
        return finalize_initialise();
    }
    async function finalize_initialise() {
        // À remplir
    }

    // … on continuera avec `inline fn accrue()` …
}
