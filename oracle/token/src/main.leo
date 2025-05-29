////////////////////////////////////////////////////////////////////////////////
// Eclipse Oracle – Token v2
//
// Author : **Florent Gaujal** <https://github.com/floflo777>
// Date   : 2025-05-10
//
// ### Purpose
// Life-cycle manager for the **Eclipse Oracle ERC-20-like token** (on Aleo):
// - one-shot registration with `token_registry.aleo`,
// - controlled minting for airdrop, rewards, liquidity & team vesting,
// - role delegation to staking & aggregation contracts,
// - linear unlock schedules (24 monthly PERIODS).
//
// ### Storage
// | Mapping             | Key                   | Value | Description                                 |
// |---------------------|-----------------------|-------|---------------------------------------------|
// | `airdrop_done`      | `TOKEN_ID`            | bool  | True once the initial 8-provider airdrop ran|
// | `role_granted`      | `TREASURY‖TOKEN_ID`   | bool  | Prevents duplicate role grants              |
// | `rewards_done`      | `TOKEN_ID`            | bool  | Flag after reward pool is provisioned       |
// | `liquidity_last_block`| `TOKEN_ID`          | u32   | Last unlock block for liquidity vault       |
// | `team_last_block`   | `TOKEN_ID`            | u32   | Last unlock block for team vesting          |
//
// ### Invariants
// - **Token supply ≤ `MAX_SUPPLY`** enforced by `token_registry.aleo`.
// - Each “once” action (airdrop, rewards pool, role grant) is guarded by
//   a boolean flag.
// - Linear unlocks respect the `PERIOD_BLOCKS` spacing.
//
import token_registry.aleo;

program eclipse_oracle_token_2.aleo {

    // --------------------------------------------------------------------
    //  Basic token metadata
    // --------------------------------------------------------------------
    const TOKEN_ID: field = 123456789101field;
    const NAME: u128 = 332565922916059772120165u128;  // "EclipseOracle"
    const SYMBOL: u128 = 1179406164u128;              // "EORC" 
    const DECIMALS: u8   = 8u8;
    const MAX_SUPPLY:u128 = 1_000_000_000_000_000u128;

    // External authorization flags
    const EXTERNAL_AUTHORIZATION_REQUIRED: bool = false;
    const EXTERNAL_AUTHORIZATION_PARTY: address=aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;

    // Hard-coded destinations
    const TREASURY: address = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;
    const STAKING_CONTRACT: address = eclipse_oracle_staking_2.aleo;
    const AGGREGATE_CONTRACT:address = eclipse_oracle_aggregate_2.aleo;
    const LIQUIDITY_VAULT: address = aleo1c39lrkdvnkchl79qza20vqemyytdmye7xa8wu6pqmzeqqe400yfq4qzg6w;
    const TEAM_VESTING: address = aleo18suj4glqvejgu753r8s2u8kn57n3macu2yw06rcjpmu5kldfnqxq6g8kqd;

    // Tokenomics slices
    const AIRDROP_AMOUNT: u128 = MAX_SUPPLY * 1u128  / 100u128;  //  1 %
    const REWARDS_AMOUNT: u128 = MAX_SUPPLY * 40u128 / 100u128;  // 40 %
    const LIQUIDITY_AMOUNT:u128 = MAX_SUPPLY * 40u128 / 100u128;  // 40 %
    const TEAM_AMOUNT: u128 = MAX_SUPPLY * 19u128 / 100u128;  // 19 %

    // Vesting schedule (monthly over 24 PERIODS)
    const PERIODS: u128 = 24u128;
    const TEAM_SLICE: u128 = TEAM_AMOUNT / PERIODS;
    const LIQUIDITY_SLICE: u128 = LIQUIDITY_AMOUNT/ PERIODS;
    const PERIOD_BLOCKS: u32  = 864000u32;  

    // --------------------------------------------------------------------
    //  Persistent storage
    // --------------------------------------------------------------------
    mapping airdrop_done: field => bool;
    mapping role_granted: field => bool;
    mapping rewards_done: field => bool;
    mapping liquidity_last_block:field => u32;
    mapping team_last_block: field => u32;

    const supply_manager_role: u8 = 3u8;    // Role id understood by registry

    // ====================================================================
    // 1. Token registration (one-time)
    // ====================================================================
    //
    async transition initialize(
        public caller: address,
        public start_block:u32
    ) -> Future {
        assert(caller == TREASURY);   // only DAO/TREASURY can bootstrap
        let fut: Future = token_registry.aleo/register_token(
            TOKEN_ID,
            NAME,
            SYMBOL,
            DECIMALS,
            MAX_SUPPLY,
            EXTERNAL_AUTHORIZATION_REQUIRED,
            EXTERNAL_AUTHORIZATION_PARTY
        );
        return finalize_initialize(fut, start_block);
    }

    async function finalize_initialize(
        fut: Future,
        public start_block: u32
    ) {
        fut.await();
        // Seed vesting timers
        team_last_block.set(TOKEN_ID, start_block);
        liquidity_last_block.set(TOKEN_ID, start_block);
    }

    // ====================================================================
    // 2. Airdrop to the first 8 providers (once)
    // ====================================================================
    async transition airdrop_initial(
        public p0: address, public p1: address, public p2: address, public p3: address,
        public p4: address, public p5: address, public p6: address, public p7: address,
        public caller: address
    ) -> Future {
        assert(caller == TREASURY);
        let per: u128 = AIRDROP_AMOUNT / 8u128;

        // Mint in parallel to eight addresses
        let f0: Future = token_registry.aleo/mint_public(TOKEN_ID, p0, per, 0u32);
        let f1: Future = token_registry.aleo/mint_public(TOKEN_ID, p1, per, 0u32);
        let f2: Future = token_registry.aleo/mint_public(TOKEN_ID, p2, per, 0u32);
        let f3: Future = token_registry.aleo/mint_public(TOKEN_ID, p3, per, 0u32);
        let f4: Future = token_registry.aleo/mint_public(TOKEN_ID, p4, per, 0u32);
        let f5: Future = token_registry.aleo/mint_public(TOKEN_ID, p5, per, 0u32);
        let f6: Future = token_registry.aleo/mint_public(TOKEN_ID, p6, per, 0u32);
        let f7: Future = token_registry.aleo/mint_public(TOKEN_ID, p7, per, 0u32);

        return finalize_airdrop(f0, f1, f2, f3, f4, f5, f6, f7);
    }

    async function finalize_airdrop(
        f0: Future, f1: Future, f2: Future, f3: Future,
        f4: Future, f5: Future, f6: Future, f7: Future
    ) {
        let done: bool = airdrop_done.get_or_use(TOKEN_ID, false);
        assert(!done);                     // can run only once
        airdrop_done.set(TOKEN_ID, true);
        f0.await(); f1.await(); f2.await(); f3.await();
        f4.await(); f5.await(); f6.await(); f7.await();
    }

    // ====================================================================
    // 3. Grant mint-roles to staking & aggregate contracts (once)
    // ====================================================================
    async transition grant_role(
        public caller: address
    ) -> Future {
        assert(caller == TREASURY);
        let f_s: Future = token_registry.aleo/set_role(TOKEN_ID, STAKING_CONTRACT,   supply_manager_role);
        let f_a: Future = token_registry.aleo/set_role(TOKEN_ID, AGGREGATE_CONTRACT, supply_manager_role);
        return finalize_grant_role(f_s, f_a);
    }

    async function finalize_grant_role(
        f_s: Future,
        f_a: Future
    ) {
        let key: field = (TREASURY as field) + TOKEN_ID;
        assert(!role_granted.get_or_use(key, false));
        role_granted.set(key, true);
        f_s.await(); f_a.await();
    }

    // ====================================================================
    // 4. Provision rewards pool for Staking (once)
    // ====================================================================
    async transition provision_rewards_pool(
        public caller: address
    ) -> Future {
        assert(caller == TREASURY);
        let fut: Future = token_registry.aleo/mint_public(
            TOKEN_ID,
            STAKING_CONTRACT,
            REWARDS_AMOUNT,
            0u32
        );
        return finalize_rewards_pool(fut);
    }

    async function finalize_rewards_pool(
        fut: Future
    ) {
        let done: bool = rewards_done.get_or_use(TOKEN_ID, false);
        assert(!done);
        rewards_done.set(TOKEN_ID, true);
        fut.await();
    }

    // ====================================================================
    // 5. Linear unlock for liquidity vault (monthly)
    // ====================================================================
    async transition unlock_liquidity(
        public caller: address,
        public current_block:u32
    ) -> Future {
        assert(caller == TEAM_VESTING);
        let fut: Future = token_registry.aleo/mint_public(
            TOKEN_ID,
            LIQUIDITY_VAULT,
            LIQUIDITY_SLICE,
            0u32
        );
        return finalize_unlock_liquidity(fut, current_block);
    }

    async function finalize_unlock_liquidity(
        fut: Future,
        public current_block: u32
    ) {
        let last: u32 = liquidity_last_block.get_or_use(TOKEN_ID, 0u32);
        assert(current_block >= last + PERIOD_BLOCKS);
        liquidity_last_block.set(TOKEN_ID, last + PERIOD_BLOCKS);
        fut.await();
    }

    // ====================================================================
    // 6. Linear unlock for team vesting (monthly)
    // ====================================================================
    async transition unlock_team(
        public caller: address,
        public current_block:u32
    ) -> Future {
        assert(caller == TEAM_VESTING);
        let fut: Future = token_registry.aleo/mint_public(
            TOKEN_ID,
            TEAM_VESTING,
            TEAM_SLICE,
            0u32
        );
        return finalize_unlock_team(fut, current_block);
    }

    async function finalize_unlock_team(
        fut: Future,
        public current_block: u32
    ) {
        let last: u32 = team_last_block.get_or_use(TOKEN_ID, 0u32);
        assert(current_block >= last + PERIOD_BLOCKS);
        team_last_block.set(TOKEN_ID, last + PERIOD_BLOCKS);
        fut.await();
    }

    // ====================================================================
    // 7. Emergency: update token admin in the registry
    // ====================================================================
    async transition update_admin(public admin: address) -> Future {
        assert(self.caller == TREASURY);
        let fut: Future = token_registry.aleo/update_token_management(
            TOKEN_ID,
            admin,
            EXTERNAL_AUTHORIZATION_PARTY
        );
        return finalize_update_admin(fut);
    }

    async function finalize_update_admin(fut: Future) {
        fut.await();
    }
}
