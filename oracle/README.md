# Eclipse Oracle – Aleo Price Oracle Suite 🚀

> Reliable, incentive-aligned price feeds for private applications on the Aleo blockchain

---

## Table of contents

1. [💡 Project goal](#project-goal)  
2. [🏗 Architecture](#architecture)  
3. [🔄 Workflow](#workflow)  
4. [📦 Full deployment guide](#full-deployment-guide)  
5. [✍️ Credits](#credits)

---

## 💡 Project goal

Eclipse Oracle is a decentralized oracle designed for **Aleo**. It lets an arbitrary set of **providers** stake tokens, submit raw prices and get rewarded when honest, while being **slashed** when dishonest. A lightweight **aggregator** periodically computes the on-chain median that consumers can trust.

**Features**  
- ✅ Crypto-economic security (collateral staking & multi-party slashing)  
- ⚙️ Configurable feeds (min stake, windows, thresholds)  
- 📈 Linear token emissions to bootstrap liquidity & reward ecosystem actors

---

## 🏗 Architecture

### Components

| Contract          | File                              | Responsibility                                        |
| ----------------- | --------------------------------- | ----------------------------------------------------- |
| **Feed registry** | `eclipse_oracle_feed.aleo`        | Create, pause & resume price feeds                    |
| **Staking**       | `eclipse_oracle_staking_2.aleo`   | Collateral staking, provider list & slashing          |
| **Submit**        | `eclipse_oracle_submit_2.aleo`    | Provider price submissions & micro-rewards            |
| **Aggregate**     | `eclipse_oracle_aggregate_2.aleo` | Median computation, aggregator reward & slashing logic|
| **Token**         | `eclipse_oracle_token_2.aleo`     | ERC-20-like token with vesting & reward buckets       |

### Contract summaries

- **feed.aleo**  
  - `create_feed` → register a new feed with parameters  
  - `pause_feed`  → emergency stop submissions & staking  
  - `resume_feed` → lift emergency pause  

- **staking.aleo**  
  - `stake`   → lock tokens & join up to 8 providers  
  - `withdraw`→ unlock tokens (must maintain min_stake or exit)  
  - `slash`   → burn stake of dishonest provider  
  - `add_provider` → replace lowest staker if list full  

- **submit.aleo**  
  - `submit_price` → publish price (cooldown per provider)  
  - `claim_pending_reward` → mint accrued rewards in one go  

- **aggregate.aleo**  
  - `propose`          → submit candidate median  
  - `slash_aggregator` → punish bad aggregator  
  - `slash_provider`   → punish outlier price provider  
  - `finalize_aggregate` → confirm median if unchallenged  

- **token.aleo**  
  - `initialize`           → one-shot token registration  
  - `airdrop_initial`      → 1% airdrop to first 8 providers  
  - `grant_role`           → delegate mint rights to staking & aggregate  
  - `provision_rewards_pool` → mint 40% to staking contract  
  - `unlock_liquidity` & `unlock_team` → monthly linear vesting  
  - `update_admin`         → emergency admin change  

---

## 🔄 Workflow

1. **Creator** deploys all contracts and initializes the token.  
2. **Creator** registers a new *feed* with its economic parameters.  
3. **Providers** stake ≥ min_stake tokens → join provider set.  
4. Providers **submit** prices every aggregation_window blocks → micro-rewards accrue.  
5. Any provider can **propose** the median once enough fresh prices exist.  
6. A challenge_window opens where anyone may **slash** a wrong proposal.  
7. If unchallenged, proposer **finalizes** and earns aggregator_reward.  
8. Slashed stake is partially burned and partially awarded to the **slasher**.

---

## 📦 Full deployment guide

### Prerequisites

- **Aleo account** with sufficient testnet credits  
- LEO ≥ 2.5.0  
- Environment variables:
  ```sh
  export NETWORK=testnet
  export ENDPOINT=https://api.explorer.provable.com/v1
  export PK_CREATOR=<private_key_creator>
  export ADDR_CREATOR=<aleo_addr_creator>
  export TOKEN_ID=123456789101field
  ```

### 1. Deploy all contracts

```sh
# Run inside each contract directory (feed, staking, submit, aggregate, token)
leo deploy --network $NETWORK --private-key "$PK_CREATOR"
```

### 2. Initialize token & allocate genesis balances

```sh
# Register token
leo execute --program eclipse_oracle_token_2.aleo \
           initialize $ADDR_CREATOR <start_block>u32 \
           --private-key "$PK_CREATOR" --broadcast --endpoint $ENDPOINT
```

```sh
# Airdrop to first 8 providers
leo execute --program eclipse_oracle_token_2.aleo \
           airdrop_initial <p0> … <p7> $ADDR_CREATOR \
           --private-key "$PK_CREATOR" --broadcast --endpoint $ENDPOINT
```

```sh
# Grant mint role to staking & aggregate
leo execute --program eclipse_oracle_token_2.aleo \
           grant_role $ADDR_CREATOR \
           --private-key "$PK_CREATOR" --broadcast --endpoint $ENDPOINT
```


### 3. Create a new feed

```sh
leo execute --program eclipse_oracle_feed.aleo \
           create_feed <id>field <min_stake>u64 <spread>u64 <aggr_window>u32 <val_window>u32 $ADDR_CREATOR \
           --private-key "$PK_CREATOR" --broadcast --endpoint $ENDPOINT
```

### 4. Provider actions

```sh
# Stake tokens
leo execute --program eclipse_oracle_staking_2.aleo \
           stake <id>field 10000000000u128 $ADDR_PROVIDER \
           --private-key "$PK_PROVIDER" --broadcast --endpoint $ENDPOINT
```

```sh
# Submit price
leo execute --program eclipse_oracle_submit_2.aleo \
           submit_price <id>field 235400000000000000u128 $ADDR_PROVIDER \
           --private-key "$PK_PROVIDER" --broadcast --endpoint $ENDPOINT
```

```sh
# Propose median
leo execute --program eclipse_oracle_aggregate_2.aleo \
           propose <id>field 235400000000000000u128 $ADDR_PROVIDER \
           --private-key "$PK_PROVIDER" --broadcast --endpoint $ENDPOINT
```

```sh
# Finalize after challenge period
leo execute --program eclipse_oracle_aggregate_2.aleo \
           finalize_aggregate <id>field $ADDR_PROVIDER \
           --private-key "$PK_PROVIDER" --broadcast --endpoint $ENDPOINT
```

--- 

## ✍️ Credits

Developed with ❤️ by Florent Gaujal
https://github.com/floflo777
