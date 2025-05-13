# SDK Eclipse Oracle – Aleo

> Outils TypeScript pour interagir avec les contrats Eclipse Oracle sur Aleo

---

## Table des matières

1. [Objectif du projet](#objectif-du-projet)
2. [Architecture](#architecture)
3. [Utilisation](#utilisation)
4. [Scripts principaux](#scripts-principaux)
5. [Configuration](#configuration)
6. [Crédits](#crédits)

---

## Objectif du projet

Le SDK Eclipse Oracle fournit des scripts et utilitaires TypeScript pour faciliter l'interaction avec les contrats intelligents Eclipse Oracle déployés sur le réseau Aleo. Il permet notamment :

- De soumettre des prix on-chain en tant que provider
- De staker ou retirer des tokens
- De récupérer la hauteur de bloc courante
- De surveiller et automatiser les interactions avec l'oracle

---

## Architecture

Le SDK est organisé autour de scripts TypeScript principaux :

| Script      | Rôle principal                                                   |
| ----------- | ---------------------------------------------------------------- |
| `submit.ts` | Récupère le prix ALEO/USD et le soumet on-chain                  |
| `stake.ts`  | Permet de staker ou retirer des tokens                           |
| `height.ts` | Récupère la hauteur de bloc courante via l'explorer              |
| `slash.ts`  | Permet d'initier un slashing contre un provider ou un agrégateur |

Chaque script utilise le SDK [@provablehq/sdk](https://www.npmjs.com/package/@provablehq/sdk) pour interagir avec le réseau Aleo.

---

## Utilisation

### Prérequis

- Node.js ≥ 18
- Un compte Aleo avec des crédits testnet
- Variables d'environnement correctement configurées (voir ci-dessous)

### Installation

```sh
npm install
```

### Exécution d'un script

```sh
# Exemple : soumettre un prix
npx ts-node sdk/src/submit.ts

# Staker des tokens
npx ts-node sdk/src/stake.ts

# Récupérer la hauteur de bloc
npx ts-node sdk/src/height.ts

# Initier un slashing
npx ts-node sdk/src/slash.ts
```

---

## Scripts principaux

### `submit.ts`

- Récupère le prix ALEO/USD depuis plusieurs API (CoinGecko, CoinMarketCap, CoinStats)
- Calcule la moyenne et la soumet au contrat `eclipse_oracle_submit_2.aleo`
- Gère la fenêtre d'exécution et attend la confirmation de la transaction

### `stake.ts`

- Permet de staker ou retirer des tokens sur le contrat `eclipse_oracle_staking_2.aleo`
- Gère les interactions de base pour devenir provider ou retirer sa mise

### `height.ts`

- Récupère la hauteur de bloc courante via l'API de l'explorer

### `slash.ts`

- Permet d'initier une action de slashing contre un fournisseur de prix (`provider`) ou un agrégateur (`aggregator`).
- Interagit avec les fonctions `slash_provider` et `slash_aggregator` du contrat `eclipse_oracle_aggregate_2.aleo`.
- Nécessite la configuration de l'action à mener (`SLASH_ACTION`) et, le cas échéant, de l'adresse du provider à slasher (`PROVIDER_TO_SLASH_ADDRESS`).

---

## Configuration

Les scripts nécessitent plusieurs variables d'environnement :

- `PK_PROVIDER` : Clé privée du provider (pour `submit.ts`, `stake.ts`)
- `ADDR_PROVIDER` : Adresse Aleo du provider (pour `submit.ts`, `stake.ts`)
- `PK_SLASHER` : Clé privée du slasheur (pour `slash.ts`)
- `ADDR_SLASHER` : Adresse Aleo du slasheur (pour `slash.ts`)
- `EXPLORER_ENDPOINT` : Endpoint de l'explorer Aleo (commun à tous les scripts)
- `RPC_ENDPOINT` : Endpoint RPC Aleo (commun à tous les scripts)
- `STAKE_RECORD_ID` : Identifiant du record de staking (pour `submit.ts`, `stake.ts`, potentiellement d'autres interactions liées au staking)
- `FEED_ID`: Identifiant du feed concerné par le slashing (pour `slash.ts`)
- `AGGREGATE_PROGRAM_ID`: Nom du programme Aleo pour l'agrégation et le slashing (ex: `eclipse_oracle_aggregate_2.aleo`, pour `slash.ts`)
- `SUBMIT_PROGRAM_ID`: Nom du programme Aleo pour la soumission de prix (ex: `eclipse_oracle_submit_2.aleo`, pour `submit.ts`)
- `STAKE_PROGRAM_ID`: Nom du programme Aleo pour le staking (ex: `eclipse_oracle_staking_2.aleo`, pour `stake.ts`)
- `SLASH_ACTION`: Action de slashing à effectuer (`provider` ou `aggregator`, pour `slash.ts`)
- `PROVIDER_TO_SLASH_ADDRESS` (optionnel): Adresse du provider à slasher (pour `slash.ts` si `SLASH_ACTION` est `provider`)
- `INTERVAL` : Taille de la fenêtre d'agrégation (principalement pour `submit.ts`)
- `MARGIN` : Marge de sécurité pour la soumission (principalement pour `submit.ts`)
- `FEE` : Frais de transaction (commun à tous les scripts effectuant des transactions)
- `CMC_API_KEY` : API key CoinMarketCap (pour `submit.ts`)
- `CS_API_KEY` : API key CoinStats (pour `submit.ts`)

Exemple :

```sh
# Pour les opérations de provider (submit, stake)
export PK_PROVIDER=...
export ADDR_PROVIDER=...
export STAKE_RECORD_ID=... # ex: 123456789101
export SUBMIT_PROGRAM_ID=eclipse_oracle_submit_2.aleo
export STAKE_PROGRAM_ID=eclipse_oracle_staking_2.aleo
export INTERVAL=100
export MARGIN=10
export CMC_API_KEY=...
export CS_API_KEY=...

# Pour les opérations de slashing
export PK_SLASHER=...
export ADDR_SLASHER=...
export FEED_ID=myfeed # ou un id numérique
export AGGREGATE_PROGRAM_ID=eclipse_oracle_aggregate_2.aleo
export SLASH_ACTION=provider # ou aggregator
export PROVIDER_TO_SLASH_ADDRESS=aleo1... # Si SLASH_ACTION=provider

# Variables communes
export EXPLORER_ENDPOINT=https://api.explorer.provable.com/v1/testnet
export RPC_ENDPOINT=https://vm.aleo.org/api # ou votre endpoint RPC dédié
export FEE=1000000 # ex: 1 crédit Aleo en microcrédits
```

---

## Crédits

© ENSIMAG — Hackathon ALEO 2025
