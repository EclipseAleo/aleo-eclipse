# Eclipse Oracle – Aleo Price Oracle Suite

> Reliable, incentive‑aligned price feeds for private applications on the Aleo blockchain

---

## Table of contents

1. [Project goal](#project-goal)
2. [Architecture](#architecture)
3. [Workflow](#workflow)
4. [Full deployment guide](#full-deployment-guide)
5. [Credits](#credits)

---

## Project goal

Eclipse Oracle is a decentralized oracle designed for **Aleo**. It lets an arbitrary set of **providers** stake tokens, submit raw prices and get rewarded when honest, while being **slashed** when dishonest. A lightweight **aggregator** periodically computes the on‑chain median that consumers can trust.

*Features*

* **Crypto‑economic security** based on collateral staking and multi‑party slashing.
* **Configurable feeds** (min stake, aggregation window, challenge window…).
* **Linear token emissions** to bootstrap liquidity and reward ecosystem actors.

---

## Architecture 

### Components

| Contract          | File                              | Responsibility                                        |
| ----------------- | --------------------------------- | ----------------------------------------------------- |
| **Feed registry** | `eclipse_oracle_feed.aleo`        | Create, pause and resume price feeds                            |
| **Staking**       | `eclipse_oracle_staking_2.aleo`   | Collateral staking, provider list, slashing           |
| **Submit**        | `eclipse_oracle_submit_2.aleo`    | Provider price submissions & micro‑rewards            |
| **Aggregate**     | `eclipse_oracle_aggregate_2.aleo` | Median computation, aggregator reward, slashing logic |
| **Token**         | `eclipse_oracle_token_2.aleo`     | Fungible token with vesting & reward buckets          |

### feed.aleo
Create a feed, pause a feed or resume a feed.
When creating a feed, use these parameters :
  public feed_id: field             : id of the field
  public min_stake: u64             : minimum stake amount to punish the provider for a bad feed
  public slashing_threshold: u64    : maximum spread authorized between the median and the provider feed
  public aggregation_window: u32    : time between two prices. Provider must submit a price before the end of this window else he is ban
  public challenge_window: u32      : time before a feed is validated
  public caller: address            : called address

### staking.aleo
Stake a certain amount of tokens or withdraw these tokens. First stake submission must be above the min_stake amount in order to avoid replacing a dead provider by a new one with a low stake. First 8 stakers are automatically providers. 

Replace a provider with add_provider if the new provider has more tokens in stake than the lowest stake of the 8 providers.

Providers earn tokens as a reward for each feed provided.

### submit.aleo
Submit a price whenever needed. A provider must submit a price before the end of each aggregation window. E.g : aggregation window = 100s => each provider must submit a price each 99 seconds or they will be ban.

In order to reduce gas fees providers can claim their rewards all in one with claim_pending_reward.

### aggregate.aleo
Only one price can be accepted between two aggregation_window. It can be submitted with propose. 

If the median isn't a valid price, one can call slash_aggregator. It will then verify if the proposed median is indeed wrong or not. If it is wrong the aggregator is slashed and loses its stake. The slasher can they claim an award by minting new tokens. For the next versions the slasher will be able to get the aggregator's stake directly, without minting new tokens.

If no-one has proven that the median is false, then the aggregator can call finalize_aggregate to confirm the price. They will then receive tokens as an award.

If a provider lies about a price one can call slash_provider which will verify if his price is between the median price and the slashing spread (given as an argument in the feed). He will then be ban and the slasher will be able to mint tokens as an award. For the next versions the slasher will be able to get the provider's stake directly, without minting new tokens.

### token.aleo 
The governance token used to reward providers, aggregators and slashers. Linear vesting for the liquidity pool and for the team vesting. Inflation will be reduce in next versions by creating paybale feeds.


---

## Workflow

1. **Creator** deploys all contracts and initializes the token.
2. **Creator** registers a new *feed* with its economic parameters.
3. **Providers** stake `≥ min_stake` tokens → added to provider set.
4. Providers **submit** prices every `aggregation_window` blocks ➜ micro‑rewards accrue off‑chain.
5. Any provider can **propose** the median once enough fresh prices exist.
6. A `challenge_window` opens where anyone may **slash** a wrong proposal.
7. If not slashed, the proposer (aggregator) finalizes and gets `aggregator_reward`.
8. Slashed stake is partially burned and partially given to the **slasher**.

---

## Full deployment guide

### Prerequisites

* **Aleo account** with sufficient testnet credits.
* `LEO` ≥ 2.5.0 and `snarkOS` ≥ 2.0.0‑testnet5.
* Environment variables:

```sh
export NETWORK=testnet
export ENDPOINT=https://api.explorer.provable.com/v1
export PK_CREATOR=<private_key_creator>
export ADDR_CREATOR=<aleo_addr_creator>
export TOKEN_ID=123456789101field
```

### 1. Deploy every contract

```sh
leo deploy --network $NETWORK --private-key "$PK_CREATOR"
```

> **Tip** : the command above must be run inside **each** contract directory (`feed`, `staking`, …).

### 2. Initialize the token & allocate genesis balances

```sh
leo execute --program eclipse_oracle_token_2.aleo \
           initialize $ADDR_CREATOR <block_height>u32 \
           --private-key "$PK_CREATOR" --broadcast --endpoint $ENDPOINT

# First airdrop to 8 genesis providers
leo execute --program eclipse_oracle_token_2.aleo \
           airdrop_initial <p0> <p1> <p2> <p3> <p4> <p5> <p6> <p7> $ADDR_CREATOR \
           --private-key "$PK_CREATOR" --broadcast --endpoint $ENDPOINT

# Grant mint role to staking & aggregate contracts
leo execute --program eclipse_oracle_token_2.aleo \
           grant_role $ADDR_CREATOR \
           --private-key "$PK_CREATOR" --broadcast --endpoint $ENDPOINT
```

### 3. Create a new feed

```sh
leo execute --program eclipse_oracle_feed.aleo \
           create_feed <id>field >min_stake>u64 <spread>u64 <aggr_window>u32 <val_window>u32 $ADDR_CREATOR \
           --private-key "$PK_CREATOR" --broadcast --endpoint $ENDPOINT
```

### 4. Provider actions

```sh
# Stake 100 tokens
leo execute --program eclipse_oracle_staking_2.aleo \
           stake <id>field 10000000000u128 $ADDR_PROVIDER \
           --private-key "$PK_PROVIDER" --broadcast --endpoint $ENDPOINT

# Submit a price
leo execute --program eclipse_oracle_submit_2.aleo \
           submit_price <id>field 235400000000000000u128 $ADDR_PROVIDER \
           --private-key "$PK_PROVIDER" --broadcast --endpoint $ENDPOINT

# Propose the median
leo execute --program eclipse_oracle_aggregate_2.aleo \
           propose <id>field 235400000000000000u128 $ADDR_PROVIDER \
           --private-key "$PK_PROVIDER" --broadcast --endpoint $ENDPOINT

# Finalize after challenge period
leo execute --program eclipse_oracle_aggregate_2.aleo \
           finalize_aggregate <id>field $ADDR_PROVIDER \
           --private-key "$PK_PROVIDER" --broadcast --endpoint $ENDPOINT
```

---


## Credits

Developed by Florent Gaujal - github.io/floflo777
