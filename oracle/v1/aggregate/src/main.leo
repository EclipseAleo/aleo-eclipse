import flo_oracle_feed.aleo;
import flo_oracle_submit.aleo;
import flo_oracle_staking.aleo;

program flo_oracle_aggregate.aleo {
    const MAX_PROVIDERS: u32 = 8u32;
    const MIN_PROVIDERS: u32 = 6u32;

    struct FeedConfig {
        creator:            address,
        min_stake:          u128,
        slashing_threshold: u128,
        aggregation_window: u64,
        paused:             bool
    }

    mapping latest_price: field => u128;

    async transition aggregate(
        public feed_id: field,
        public median:  u128
    ) -> Future {
        return finalize_aggregate(feed_id, median);
    }

    async function finalize_aggregate(
        public feed_id: field,
        public median:  u128
    ) {
        let cfg: FeedConfig = Mapping::get(flo_oracle_feed.aleo/feeds, feed_id);
        assert(!cfg.paused);

        let count: u32 =
            Mapping::get_or_use(flo_oracle_staking.aleo/provider_count, feed_id, 0u32);
        assert(count >= MIN_PROVIDERS);

        let key0: field   = feed_id + (0u32 as field);
        let prov0: address = Mapping::get(flo_oracle_staking.aleo/provider_list, key0);
        let stake0: u128  =
            Mapping::get_or_use(flo_oracle_staking.aleo/stakes, feed_id + (prov0 as field), 0u128);
        assert(stake0 > 0u128);
        let price0: u128 =
            Mapping::get_or_use(flo_oracle_submit.aleo/temp_price, feed_id + (prov0 as field), 0u128);
        let cond0_le: u32 = (0u32 < count && price0 <= median) ? 1u32 : 0u32;
        let cond0_ge: u32 = (0u32 < count && price0 >= median) ? 1u32 : 0u32;

        let key1: field   = feed_id + (1u32 as field);
        let prov1: address = Mapping::get(flo_oracle_staking.aleo/provider_list, key1);
        let stake1: u128  =
            Mapping::get_or_use(flo_oracle_staking.aleo/stakes, feed_id + (prov1 as field), 0u128);
        assert(stake1 > 0u128);
        let price1: u128 =
            Mapping::get_or_use(flo_oracle_submit.aleo/temp_price, feed_id + (prov1 as field), 0u128);
        let cond1_le: u32 = (1u32 < count && price1 <= median) ? 1u32 : 0u32;
        let cond1_ge: u32 = (1u32 < count && price1 >= median) ? 1u32 : 0u32;

        let key2: field   = feed_id + (2u32 as field);
        let prov2: address = Mapping::get(flo_oracle_staking.aleo/provider_list, key2);
        let stake2: u128  =
            Mapping::get_or_use(flo_oracle_staking.aleo/stakes, feed_id + (prov2 as field), 0u128);
        assert(stake2 > 0u128);
        let price2: u128 =
            Mapping::get_or_use(flo_oracle_submit.aleo/temp_price, feed_id + (prov2 as field), 0u128);
        let cond2_le: u32 = (2u32 < count && price2 <= median) ? 1u32 : 0u32;
        let cond2_ge: u32 = (2u32 < count && price2 >= median) ? 1u32 : 0u32;

        let key3: field   = feed_id + (3u32 as field);
        let prov3: address = Mapping::get(flo_oracle_staking.aleo/provider_list, key3);
        let stake3: u128  =
            Mapping::get_or_use(flo_oracle_staking.aleo/stakes, feed_id + (prov3 as field), 0u128);
        assert(stake3 > 0u128);
        let price3: u128 =
            Mapping::get_or_use(flo_oracle_submit.aleo/temp_price, feed_id + (prov3 as field), 0u128);
        let cond3_le: u32 = (3u32 < count && price3 <= median) ? 1u32 : 0u32;
        let cond3_ge: u32 = (3u32 < count && price3 >= median) ? 1u32 : 0u32;

        let key4: field   = feed_id + (4u32 as field);
        let prov4: address = Mapping::get(flo_oracle_staking.aleo/provider_list, key4);
        let stake4: u128  =
            Mapping::get_or_use(flo_oracle_staking.aleo/stakes, feed_id + (prov4 as field), 0u128);
        assert(stake4 > 0u128);
        let price4: u128 =
            Mapping::get_or_use(flo_oracle_submit.aleo/temp_price, feed_id + (prov4 as field), 0u128);
        let cond4_le: u32 = (4u32 < count && price4 <= median) ? 1u32 : 0u32;
        let cond4_ge: u32 = (4u32 < count && price4 >= median) ? 1u32 : 0u32;

        let key5: field   = feed_id + (5u32 as field);
        let prov5: address = Mapping::get(flo_oracle_staking.aleo/provider_list, key5);
        let stake5: u128  =
            Mapping::get_or_use(flo_oracle_staking.aleo/stakes, feed_id + (prov5 as field), 0u128);
        assert(stake5 > 0u128);
        let price5: u128 =
            Mapping::get_or_use(flo_oracle_submit.aleo/temp_price, feed_id + (prov5 as field), 0u128);
        let cond5_le: u32 = (5u32 < count && price5 <= median) ? 1u32 : 0u32;
        let cond5_ge: u32 = (5u32 < count && price5 >= median) ? 1u32 : 0u32;

        let key6: field   = feed_id + (6u32 as field);
        let prov6: address = Mapping::get(flo_oracle_staking.aleo/provider_list, key6);
        let stake6: u128  =
            Mapping::get_or_use(flo_oracle_staking.aleo/stakes, feed_id + (prov6 as field), 0u128);
        assert(stake6 > 0u128);
        let price6: u128 =
            Mapping::get_or_use(flo_oracle_submit.aleo/temp_price, feed_id + (prov6 as field), 0u128);
        let cond6_le: u32 = (6u32 < count && price6 <= median) ? 1u32 : 0u32;
        let cond6_ge: u32 = (6u32 < count && price6 >= median) ? 1u32 : 0u32;

        let key7: field   = feed_id + (7u32 as field);
        let prov7: address = Mapping::get(flo_oracle_staking.aleo/provider_list, key7);
        let stake7: u128  =
            Mapping::get_or_use(flo_oracle_staking.aleo/stakes, feed_id + (prov7 as field), 0u128);
        assert(stake7 > 0u128);
        let price7: u128 =
            Mapping::get_or_use(flo_oracle_submit.aleo/temp_price, feed_id + (prov7 as field), 0u128);
        let cond7_le: u32 = (7u32 < count && price7 <= median) ? 1u32 : 0u32;
        let cond7_ge: u32 = (7u32 < count && price7 >= median) ? 1u32 : 0u32;

        let sum_le: u32 = 
            cond0_le + cond1_le + cond2_le + cond3_le +
            cond4_le + cond5_le + cond6_le + cond7_le;
        let sum_ge: u32 = 
            cond0_ge + cond1_ge + cond2_ge + cond3_ge +
            cond4_ge + cond5_ge + cond6_ge + cond7_ge;

        let needed: u32 = (count / 2u32) + 1u32;
        assert(sum_le >= needed);
        assert(sum_ge >= needed);

        let threshold: u128 = cfg.slashing_threshold;
        for i: u32 in 0u32..MAX_PROVIDERS {
            if (i < count) {
                let slot_i: field   = feed_id + (i as field);
                let prov_i: address = Mapping::get(flo_oracle_staking.aleo/provider_list, slot_i);
                let price_i: u128   = Mapping::get_or_use(
                    flo_oracle_submit.aleo/temp_price,
                    feed_id + (prov_i as field),
                    0u128
                );
                let diff: u128 = (price_i >= median) 
                    ? (price_i - median) 
                    : (median - price_i);
                assert(diff <= threshold);
            }
        }


        Mapping::set(latest_price, feed_id, median);
    }
}
