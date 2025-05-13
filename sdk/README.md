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

| Script      | Rôle principal                                      |
| ----------- | --------------------------------------------------- |
| `submit.ts` | Récupère le prix ALEO/USD et le soumet on-chain     |
| `stake.ts`  | Permet de staker ou retirer des tokens              |
| `height.ts` | Récupère la hauteur de bloc courante via l'explorer |

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
npx ts-node sdk/submit.ts

# Staker des tokens
npx ts-node sdk/stake.ts

# Récupérer la hauteur de bloc
npx ts-node sdk/height.ts
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

---

## Configuration

Les scripts nécessitent plusieurs variables d'environnement :

- `PK_PROVIDER` : Clé privée du provider
- `ADDR_PROVIDER` : Adresse Aleo du provider
- `EXPLORER_ENDPOINT` : Endpoint de l'explorer Aleo
- `RPC_ENDPOINT` : Endpoint RPC Aleo
- `STAKE_RECORD_ID` : Identifiant du record de staking
- `INTERVAL` : Taille de la fenêtre d'agrégation
- `MARGIN` : Marge de sécurité pour la soumission
- `FEE` : Frais de transaction
- `CMC_API_KEY` : API key CoinMarketCap
- `CS_API_KEY` : API key CoinStats

Exemple :

```sh
export PK_PROVIDER=... # clé privée
export ADDR_PROVIDER=... # adresse Aleo
export EXPLORER_ENDPOINT=https://api.explorer.provable.com/v1/testnet
export RPC_ENDPOINT=https://vm.aleo.org/api
export STAKE_RECORD_ID=... # ex: 123456789101
export INTERVAL=100
export MARGIN=10
export FEE=0.05
export CMC_API_KEY=... # clé API CoinMarketCap
export CS_API_KEY=... # clé API CoinStats
```

---

## Crédits

© ENSIMAG — Hackathon ALEO 2025
