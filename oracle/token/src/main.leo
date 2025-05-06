import token_registry.aleo;

program eclipse_oracle_token.aleo {
    const token_id: field = 12345678910field;
    const name: u128 = 332565922916059772120165u128;
    const symbol: u128 = 1179406164u128;
    const decimals: u8 = 8u8;
    const max_supply: u128 = 1_000_000_000_000_000u128;

    const external_authorization_required: bool = false;
    const external_authorization_party: address = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;

    const treasury: address = aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv;
    const staking_contract: address = eclipse_oracle_staking.aleo;
    const aggregate_contract: address = eclipse_oracle_aggregate.aleo;
    const liquidity_vault: address = aleo1c39lrkdvnkchl79qza20vqemyytdmye7xa8wu6pqmzeqqe400yfq4qzg6w;
    const team_vesting: address = aleo18suj4glqvejgu753r8s2u8kn57n3macu2yw06rcjpmu5kldfnqxq6g8kqd;

    const airdrop_amount: u128 = max_supply * 1u128 / 100u128;
    const rewards_amount: u128 = max_supply * 40u128 / 100u128;
    const liquidity_amount: u128 = max_supply * 40u128 / 100u128;
    const team_amount: u128 = max_supply * 19u128 / 100u128;

    const periods: u128 = 24u128;
    const team_slice: u128 = team_amount / periods;
    const liquidity_slice: u128 = liquidity_amount / periods;
    const period_blocks: u32 = 864000u32;

    mapping airdrop_done: field => bool;
    mapping role_granted: field => bool;
    mapping rewards_done: field => bool;
    mapping liquidity_last_block: field => u32;
    mapping team_last_block: field => u32;

    const supply_manager_role: u8 = 3u8;

    // --------------------------------------------------------
    // 1. Enregistrement du token
    // --------------------------------------------------------
    async transition initialize(
        public caller: address,
        public start_block: u32
    ) -> Future {
        assert(caller == treasury);
        let f: Future = token_registry.aleo/register_token(
            token_id,
            name,
            symbol,
            decimals,
            max_supply,
            external_authorization_required,
            external_authorization_party
        );
        return finalize_initialize(f,start_block);
    }

    async function finalize_initialize(
        f: Future,
        public start_block: u32
    ) {
        f.await();
        team_last_block.set(token_id,start_block);
        liquidity_last_block.set(token_id,start_block);
    }


    // --------------------------------------------------------
    // 2. Airdrop pour les premiers providers
    // --------------------------------------------------------
    async transition airdrop_initial(
        public p0: address, public p1: address,
        public p2: address, public p3: address,
        public p4: address, public p5: address,
        public p6: address, public p7: address,
        public caller: address
    ) -> Future {
        assert(caller == treasury);
        let per: u128 = airdrop_amount / 8u128;
        let f0: Future = token_registry.aleo/mint_public(token_id,p0,per,0u32);
        let f1: Future = token_registry.aleo/mint_public(token_id,p1,per,0u32);
        let f2: Future = token_registry.aleo/mint_public(token_id,p2,per,0u32);
        let f3: Future = token_registry.aleo/mint_public(token_id,p3,per,0u32);
        let f4: Future = token_registry.aleo/mint_public(token_id,p4,per,0u32);
        let f5: Future = token_registry.aleo/mint_public(token_id,p5,per,0u32);
        let f6: Future = token_registry.aleo/mint_public(token_id,p6,per,0u32);
        let f7: Future = token_registry.aleo/mint_public(token_id,p7,per,0u32);
        return finalize_airdrop(f0,f1,f2,f3,f4,f5,f6,f7);
    }
    async function finalize_airdrop(
        f0: Future,f1: Future,f2: Future,f3: Future,
        f4: Future,f5: Future,f6: Future,f7: Future
    ) {
        let done: bool = airdrop_done.get_or_use(token_id,false);
        assert(!done);
        airdrop_done.set(token_id,true);
        f0.await(); f1.await(); f2.await(); f3.await();
        f4.await(); f5.await(); f6.await(); f7.await();
    }


    // --------------------------------------------------------
    // 3. Roles pour mint
    // --------------------------------------------------------
    async transition grant_role(
        public caller: address
    ) -> Future {
        assert(caller == treasury);
        let f_s: Future = token_registry.aleo/set_role(token_id,staking_contract,supply_manager_role);
        let f_a: Future = token_registry.aleo/set_role(token_id,aggregate_contract,supply_manager_role);
        return finalize_grant_role(f_s,f_a);
    }
    async function finalize_grant_role(
        f_s: Future,
        f_a: Future
    ) {
        let key: field = (treasury as field) + token_id;
        assert(!role_granted.get_or_use(key,false));
        role_granted.set(key,true);
        f_s.await();
        f_a.await();
    }


    // --------------------------------------------------------
    // 4. Pool de liquidite
    // --------------------------------------------------------
    async transition provision_rewards_pool(
        public caller: address
    ) -> Future {
        assert(caller == treasury);
        let f: Future = token_registry.aleo/mint_public(
            token_id,
            staking_contract,
            rewards_amount,
            0u32
        );
        return finalize_rewards_pool(f);
    }
    async function finalize_rewards_pool(
        f: Future
    ) {
        let done: bool = rewards_done.get_or_use(token_id,false);
        assert(!done);
        rewards_done.set(token_id,true);
        f.await();
    }


    // --------------------------------------------------------
    // 5. Unlock lineaire pour la liqudite
    // --------------------------------------------------------
    async transition unlock_liquidity(
        public caller: address,
        public current_block: u32
    ) -> Future {
        assert(caller == team_vesting);
        let f: Future = token_registry.aleo/mint_public(
            token_id,
            liquidity_vault,
            liquidity_slice,
            0u32
        );
        return finalize_unlock_liquidity(f,current_block);
    }
    async function finalize_unlock_liquidity(
        f: Future,
        public current_block: u32
    ) {
        let last: u32 = liquidity_last_block.get_or_use(token_id,0u32);
        assert(current_block >= last + period_blocks);
        liquidity_last_block.set(token_id,last + period_blocks);
        f.await();
    }


    // --------------------------------------------------------
    // 6. Unlock lineaire pour l'équipe
    // --------------------------------------------------------
    async transition unlock_team(
        public caller: address,
        public current_block: u32
    ) -> Future {
        assert(caller == team_vesting);
        let f: Future = token_registry.aleo/mint_public(
            token_id,
            team_vesting,
            team_slice,
            0u32
        );
        return finalize_unlock_team(f,current_block);
    }
    async function finalize_unlock_team(
        f: Future,
        public current_block: u32
    ) {
        let last: u32 = team_last_block.get_or_use(token_id,0u32);
        assert(current_block >= last + period_blocks);
        team_last_block.set(token_id,last + period_blocks);
        f.await();
    }
}
