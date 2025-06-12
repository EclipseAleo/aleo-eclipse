# 🌘 Aleo Eclipse

This repository contains all the code needed to test our **private lending platform** on the **Aleo blockchain**, along with its **on-chain oracle**.

## 🚀 How to Test the Project

To run the full project:

1. Clone the repository.
2. Use the **private key provided in `private.txt`**.
3. Set up the Aleo network in **`testnet` mode**.

This will allow you to access:
- your **test tokens**,
- the full set of **private lending features**,
- the **slashing mechanism** for oracle validators,
- and **governance rights via our token**.

> ⚠️ The private key and tokens are only valid on the test network.

---

## 📦 Project Structure

- [`oracle/`](./oracle/): contains the source code for the on-chain oracle, price updates, incentives, slashing logic, etc.  
  → See the folder’s `README.md` for more details.

- [`lending/`](./lending/): contains the contracts for the vault, treasury, and governance token.  
  → See the folder’s `README.md` for full documentation.

---
