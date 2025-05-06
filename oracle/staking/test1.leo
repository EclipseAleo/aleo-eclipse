async transition add_provider(
    public feed_id:  field,
    public provider: address
) -> Future {
    return finalize_add_provider(feed_id, provider);
}

async function finalize_add_provider(
    public feed_id:  field,
    public provider: address
) {
    let cfg: FeedConfig = flo_oracle_feed.aleo/feeds.get(feed_id);
    assert(!cfg.paused);

    let key_p: field = feed_id + (provider as field);
    let stake_p: u128 = Mapping::get_or_use(stakes, key_p, 0u128);
    assert(stake_p > 0u128);

    let count: u32 = Mapping::get_or_use(provider_count, feed_id, 0u32);
    for i: u32 in 0u32..MAX_PROVIDERS {
        if (i < count) {
            let k_i: field   = feed_id + (i as field);
            let p:     address = Mapping::get(provider_list, k_i);
            assert(p != provider);
        }
    }

    if (count < MAX_PROVIDERS) {
        let slot: field = feed_id + (count as field);
        Mapping::set(provider_list,  slot,      provider);
        Mapping::set(provider_count, feed_id, count + 1u32);
        return;
    }

    let s0: u128 = Mapping::get_or_use(stakes, feed_id + (0u32 as field), 0u128);
    let s1: u128 = Mapping::get_or_use(stakes, feed_id + (1u32 as field), 0u128);
    let less01: bool = s1 < s0;
    let m01: u128 = less01 ? s1 : s0;
    let i01: u32  = less01 ? 1u32 : 0u32;

    let s2: u128 = Mapping::get_or_use(stakes, feed_id + (2u32 as field), 0u128);
    let s3: u128 = Mapping::get_or_use(stakes, feed_id + (3u32 as field), 0u128);
    let less23: bool = s3 < s2;
    let m23: u128 = less23 ? s3 : s2;
    let i23: u32  = less23 ? 3u32 : 2u32;

    let less0123: bool = m23 < m01;
    let m0123: u128 = less0123 ? m23 : m01;
    let i0123: u32  = less0123 ? i23 : i01;

    let s4: u128 = Mapping::get_or_use(stakes, feed_id + (4u32 as field), 0u128);
    let s5: u128 = Mapping::get_or_use(stakes, feed_id + (5u32 as field), 0u128);
    let less45: bool = s5 < s4;
    let m45: u128 = less45 ? s5 : s4;
    let i45: u32  = less45 ? 5u32 : 4u32;

    let s6: u128 = Mapping::get_or_use(stakes, feed_id + (6u32 as field), 0u128);
    let s7: u128 = Mapping::get_or_use(stakes, feed_id + (7u32 as field), 0u128);
    let less67: bool = s7 < s6;
    let m67: u128 = less67 ? s7 : s6;
    let i67: u32  = less67 ? 7u32 : 6u32;

    let less4567: bool = m67 < m45;
    let m4567: u128 = less4567 ? m67 : m45;
    let i4567: u32  = less4567 ? i67 : i45;

    let less_all: bool = m4567 < m0123;
    let min_stake: u128 = less_all ? m4567 : m0123;
    let idx_min:   u32   = less_all ? i4567 : i0123;

    assert(stake_p > min_stake);

    let slot_old: field   = feed_id + (idx_min as field);
    Mapping::set(provider_list, slot_old, provider);
}