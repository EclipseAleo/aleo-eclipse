# Eclipse Lending – Aleo Vault & Treasury Suite 💰

> A decentralized lending mechanism with fee redistribution for governance token holders on the Aleo blockchain.

---

## Table of contents

1. [💡 Project goal](#project-goal)
2. [🏗 Architecture](#architecture)
3. [🔄 Workflow](#workflow)
4. [📦 Full deployment guide](#full-deployment-guide)
5. [✍️ Credits](#credits)

---

## 💡 Project goal

Eclipse Lending is a decentralized overcollateralized **USDA stablecoin vault** built for **Aleo**. Users deposit Aleo Credits as collateral, mint USDA tokens, and pay a small withdrawal fee. This fee is redirected to a **treasury contract**, which distributes earnings to **governance token holders** (ECLP).

**Features**

* ✅ Overcollateralized USDA minting using private Aleo Credits
* 🔁 Public treasury contract managing stake & rewards
* 📤 Permissionless liquidation & collateral recovery
* ⚖️ Proportional reward system for ECLP holders

**Disclaimer**

* Global flow is functional but some asserts may be missing for maximal security.

---

## 🏗 Architecture

### Components

| Contract     | File                                | Responsibility                                         |
| ------------ | ----------------------------------- | ------------------------------------------------------ |
| **Vault**    | `eclipse_lending_usda_vault_7.aleo` | Collateral deposit, USDA minting, burning, liquidation |
| **Treasury** | `eclipse_lending_treasury.aleo`     | Stake ECLP tokens, receive and claim share of fees     |
| **Token**    | `token_registry.aleo`               | USDA & ECLP token definitions and transfers            |
| **Oracle**   | `eclipse_oracle_aggregate_4.aleo`   | Latest price feed required for minting and liquidation |
| **Credits**  | `credits.aleo`                      | Transfer & handle Aleo native currency                 |

### Contract summaries

* **vault.aleo**

  * `deposit` → transfer Aleo credits to mint USDA (uses oracle price)
  * `mint` / `burn` → adjust debt against your collateral position
  * `withdraw` → take back collateral minus fee
  * `liquidate` → burn USDA to liquidate undercollateralized positions
  * `claim_refund` → recover excess USDA sent in liquidation
  * `claim_collateral` → collect the seized collateral
  * `claim_fees` → admin function to send accumulated fees to treasury

* **treasury.aleo**

  * `stake` / `withdraw` → manage ECLP governance token staking
  * `claim` → calculate and collect proportionate share of fees

---

## 🔄 Workflow

1. **Admin** deploys contracts and initializes USDA token.
2. **User** deposits Aleo Credits and oracle price → receives Position.
3. **User** mints USDA (up to a safe max debt based on collateral).
4. **User** can burn USDA to reduce debt or withdraw unlocked collateral.
5. Each withdrawal applies a **1% fee**, accumulated in `total_fees`.
6. **Admin** transfers all fees from Vault to Treasury contract.
7. **Governance token holders (ECLP)** stake into Treasury and claim rewards proportionally based on:

   * `stake` amount
   * `delta` in total fees

---

## 📦 Full deployment guide

### Prerequisites

* Aleo account with testnet credits
* LEO ≥ 2.5.0
* Environment setup:

```sh
export NETWORK=testnet
export ENDPOINT=https://api.explorer.provable.com/v1
export PK_CREATOR=APrivateKey1zkp8i2eGeSa6xuALaitK4fQMdkHBTMYXWDaXEjsGxrUPWXi
export ADDR_CREATOR=aleo1096dhxrwgf4xz857zru0uy4dxwgy4ztqqzg8fyl74luv3v79d5pslt2jjv
export USDA_ID=44556677889914field
export ECLP_ID=123field
```

### 1. Deploy all contracts

```sh
leo deploy --network $NETWORK --private-key "$PK_CREATOR"
```

### 2. Initialize USDA token (one-shot)

```sh
leo execute --program eclipse_lending_usda_vault_7.aleo \
           initialize $ADDR_CREATOR \
           --private-key "$PK_CREATOR" --broadcast --endpoint $ENDPOINT
```

### 3. Treasury – Stake and claim (ECLP token, not USDA)

```sh
# Stake ECLP tokens
leo execute --program eclipse_lending_treasury.aleo \
           stake 1000000u128 $ADDR_CREATOR \
           --private-key "$PK_CREATOR" --broadcast --endpoint $ENDPOINT
```

```sh
# Claim share of fees
leo execute --program eclipse_lending_treasury.aleo \
           claim <stake_amt> <total_staked> <last_paid> <current_fees> \
           --private-key "$PK_CREATOR" --broadcast --endpoint $ENDPOINT
```

### 4. User lifecycle

```sh
# Deposit Aleo credits
leo execute --program eclipse_lending_usda_vault_7.aleo \
           deposit <amount> <oracle_price> <last_id> $ADDR_USER <record> \
           --private-key "$PK_USER" --broadcast --endpoint $ENDPOINT
```

```sh
# Mint USDA
leo execute --program eclipse_lending_usda_vault_7.aleo \
           mint <usda_out> <price> <Position> \
           --private-key "$PK_USER" --broadcast --endpoint $ENDPOINT
```

```sh
# Burn USDA
leo execute --program eclipse_lending_usda_vault_7.aleo \
           burn <usda_in> <price> <Position> <token> \
           --private-key "$PK_USER" --broadcast --endpoint $ENDPOINT
```

---

## ✍️ Credits

Developed with ❤️ by Florent Gaujal
[https://github.com/floflo777](https://github.com/floflo777)
