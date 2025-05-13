import "dotenv/config";
import {
  Account,
  AleoNetworkClient,
  ProgramManager,
  AleoKeyProvider,
  NetworkRecordProvider,
  PrivateKey,
} from "@provablehq/sdk";
import {
  executeOnChain,
  waitForConfirmationWithTimeout,
} from "../utils/aleoUtils";
import { parseNumberEnv } from "../utils/envUtils";
// =====================================================
//  TYPES ET CONSTANTES DU MODULE
// =====================================================

export interface StakeEnv {
  PK_PROVIDER: string;
  ADDR_PROVIDER: string;
  EXPLORER_ENDPOINT: string;
  RPC_ENDPOINT: string;
  STAKE_RECORD_ID: string;
  STAKE_AMOUNT: string;
  FEE: number;
  STAKE_PROGRAM_ID: string;
}

// =====================================================
//  OUTILS DE PARSING ENV ET CONFIGURATION
// =====================================================

/**
 * Récupère et valide toutes les variables d'environnement nécessaires au staking.
 * @returns {StakeEnv} Un objet contenant toutes les variables d'environnement typées et validées.
 * @throws {Error} Si une variable obligatoire est manquante ou invalide.
 */
export function getStakeEnv(): StakeEnv {
  const {
    PK_PROVIDER,
    ADDR_PROVIDER,
    EXPLORER_ENDPOINT,
    RPC_ENDPOINT,
    STAKE_RECORD_ID,
    STAKE_AMOUNT,
    FEE,
    STAKE_PROGRAM_ID,
  } = process.env;

  const missing = [
    "PK_PROVIDER",
    "ADDR_PROVIDER",
    "EXPLORER_ENDPOINT",
    "RPC_ENDPOINT",
    "STAKE_RECORD_ID",
    "STAKE_AMOUNT",
    "FEE",
    "STAKE_PROGRAM_ID",
  ].filter((k) => !process.env[k]);
  if (missing.length) {
    throw new Error(
      "Variables d'environnement manquantes : " + missing.join(", ")
    );
  }
  return {
    PK_PROVIDER: PK_PROVIDER!,
    ADDR_PROVIDER: ADDR_PROVIDER!,
    EXPLORER_ENDPOINT: EXPLORER_ENDPOINT!,
    RPC_ENDPOINT: RPC_ENDPOINT!,
    STAKE_RECORD_ID: STAKE_RECORD_ID!,
    STAKE_AMOUNT: STAKE_AMOUNT!,
    FEE: parseNumberEnv("FEE"),
    STAKE_PROGRAM_ID: STAKE_PROGRAM_ID!,
  };
}

// =====================================================
//  LOGIQUE DE STAKE PRINCIPALE
// =====================================================

/**
 * Effectue l'opération de staking sur le smart contract Aleo.
 * @returns {Promise<void>} Rien si succès, lève une erreur sinon
 * @throws {Error} Si une étape critique échoue
 */
export async function runStake(): Promise<void> {
  const env = getStakeEnv();
  const RECORD_ID_FIELD = `${env.STAKE_RECORD_ID}field`;

  const explorerClient = new AleoNetworkClient(env.EXPLORER_ENDPOINT);
  const account = new Account({ privateKey: env.PK_PROVIDER as PrivateKey });
  const keyProvider = new AleoKeyProvider();
  const recordProvider = new NetworkRecordProvider(account, explorerClient);
  const pm = new ProgramManager(env.RPC_ENDPOINT, keyProvider, recordProvider);
  pm.setHost(env.EXPLORER_ENDPOINT);
  pm.setAccount(account);

  const inputs: string[] = [
    RECORD_ID_FIELD,
    env.STAKE_AMOUNT,
    env.ADDR_PROVIDER,
  ];

  console.log("\n--- Config ---");
  console.log("Explorer endpoint:", env.EXPLORER_ENDPOINT);
  console.log("RPC endpoint     :", env.RPC_ENDPOINT);
  console.log("Program ID       :", env.STAKE_PROGRAM_ID);
  console.log("Record ID        :", env.STAKE_RECORD_ID);
  console.log("Amount / Fee     :", env.STAKE_AMOUNT, "/", env.FEE);
  console.log("--------------------------------\n");

  console.log("📤 Diffusion de « stake » avec :");
  console.log("  programName:", env.STAKE_PROGRAM_ID);
  console.log("  inputs     :", inputs);
  console.log("  fee        :", env.FEE);

  let txId: string;
  try {
    txId = await executeOnChain(
      pm,
      {
        programName: env.STAKE_PROGRAM_ID,
        functionName: "stake",
        inputs,
        privateKey: account.privateKey(),
        privateFee: false,
        priorityFee: 0,
      },
      "stake"
    );
  } catch (err) {
    console.error("❌ Erreur durant execute() :", err);
    throw err;
  }

  console.log("⏳ En attente de confirmation…");
  let confirmation;
  try {
    confirmation = await waitForConfirmationWithTimeout(
      txId,
      env.EXPLORER_ENDPOINT
    );
  } catch (err) {
    console.error("⏰ Timeout ou erreur lors de la confirmation :", err);
    throw err;
  }
  console.log(`🎉 Transaction ${txId} status: ${confirmation.status}`);
}

// =====================================================
//  POINT D'ENTRÉE SCRIPT
// =====================================================

async function main() {
  try {
    await runStake();
  } catch (err) {
    console.error("Erreur fatale :", err);
    process.exit(1);
  }
}

main();
