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

export interface SlashEnv {
  PK_SLASHER: string;
  ADDR_SLASHER: string;
  EXPLORER_ENDPOINT: string;
  RPC_ENDPOINT: string;
  FEED_ID: string; // L'ID du feed, ex: "token1" ou un nombre, qui deviendra "token1field" ou "123field"
  FEE: number;
  AGGREGATE_PROGRAM_ID: string;
  PROVIDER_TO_SLASH_ADDRESS?: string; // Nécessaire uniquement pour slash_provider
  SLASH_ACTION: "provider" | "aggregator"; // Détermine l'action à exécuter
}

// =====================================================
//  OUTILS DE PARSING ENV ET CONFIGURATION
// =====================================================

/**
 * Récupère et valide toutes les variables d'environnement nécessaires au slashing.
 * @returns {SlashEnv} Un objet contenant toutes les variables d'environnement typées et validées.
 * @throws {Error} Si une variable obligatoire est manquante ou invalide.
 */
export function getSlashEnv(): SlashEnv {
  const {
    PK_SLASHER,
    ADDR_SLASHER,
    EXPLORER_ENDPOINT,
    RPC_ENDPOINT,
    FEED_ID,
    FEE,
    AGGREGATE_PROGRAM_ID,
    PROVIDER_TO_SLASH_ADDRESS,
    SLASH_ACTION,
  } = process.env;

  const requiredEnvVars = [
    "PK_SLASHER",
    "ADDR_SLASHER",
    "EXPLORER_ENDPOINT",
    "RPC_ENDPOINT",
    "FEED_ID",
    "FEE",
    "AGGREGATE_PROGRAM_ID",
    "SLASH_ACTION",
  ];

  const missing = requiredEnvVars.filter((k) => !process.env[k]);
  if (missing.length) {
    throw new Error(
      "Variables d'environnement manquantes : " + missing.join(", ")
    );
  }

  if (SLASH_ACTION !== "provider" && SLASH_ACTION !== "aggregator") {
    throw new Error("SLASH_ACTION doit être 'provider' ou 'aggregator'.");
  }

  if (SLASH_ACTION === "provider" && !PROVIDER_TO_SLASH_ADDRESS) {
    throw new Error(
      "PROVIDER_TO_SLASH_ADDRESS est requis pour l'action 'provider'."
    );
  }

  return {
    PK_SLASHER: PK_SLASHER!,
    ADDR_SLASHER: ADDR_SLASHER!,
    EXPLORER_ENDPOINT: EXPLORER_ENDPOINT!,
    RPC_ENDPOINT: RPC_ENDPOINT!,
    FEED_ID: FEED_ID!,
    FEE: parseNumberEnv("FEE"),
    AGGREGATE_PROGRAM_ID: AGGREGATE_PROGRAM_ID!,
    PROVIDER_TO_SLASH_ADDRESS: PROVIDER_TO_SLASH_ADDRESS,
    SLASH_ACTION: SLASH_ACTION as "provider" | "aggregator",
  };
}

// =====================================================
//  LOGIQUE DE SLASHING ON-CHAIN
// =====================================================

/**
 * Initie un slashing contre un fournisseur de prix.
 * @param pm ProgramManager initialisé.
 * @param env Variables d'environnement et de configuration.
 * @param feedIdField Identifiant du feed au format Aleo (ex: "token1field").
 * @param providerToSlashAddress Adresse Aleo du fournisseur à slasher.
 * @returns {Promise<string>} L'identifiant de la transaction de slashing.
 * @throws {Error} En cas d'échec de la transaction.
 */
export async function slashProvider(
  pm: ProgramManager,
  env: SlashEnv,
  feedIdField: string,
  providerToSlashAddress: string
): Promise<string> {
  console.log("📤 Initialisation du slashing du fournisseur...");
  const inputs: string[] = [
    feedIdField,
    providerToSlashAddress,
    env.ADDR_SLASHER,
  ];

  console.log("  Programme      :", env.AGGREGATE_PROGRAM_ID);
  console.log("  Fonction       : slash_provider");
  console.log("  Feed ID        :", feedIdField);
  console.log("  Provider à slasher:", providerToSlashAddress);
  console.log("  Slasheur       :", env.ADDR_SLASHER);
  console.log("  Frais          :", env.FEE);

  return executeOnChain(
    pm,
    {
      programName: env.AGGREGATE_PROGRAM_ID,
      functionName: "slash_provider",
      inputs,
      privateKey: env.PK_SLASHER,
      privateFee: false,
      priorityFee: env.FEE,
    },
    "slash_provider"
  );
}

/**
 * Initie un slashing contre un agrégateur.
 * @param pm ProgramManager initialisé.
 * @param env Variables d'environnement et de configuration.
 * @param feedIdField Identifiant du feed au format Aleo (ex: "token1field").
 * @returns {Promise<string>} L'identifiant de la transaction de slashing.
 * @throws {Error} En cas d'échec de la transaction.
 */
export async function slashAggregator(
  pm: ProgramManager,
  env: SlashEnv,
  feedIdField: string
): Promise<string> {
  console.log("📤 Initialisation du slashing de l'agrégateur...");
  const inputs: string[] = [feedIdField, env.ADDR_SLASHER];

  console.log("  Programme      :", env.AGGREGATE_PROGRAM_ID);
  console.log("  Fonction       : slash_aggregator");
  console.log("  Feed ID        :", feedIdField);
  console.log("  Slasheur       :", env.ADDR_SLASHER);
  console.log("  Frais          :", env.FEE);

  return executeOnChain(
    pm,
    {
      programName: env.AGGREGATE_PROGRAM_ID,
      functionName: "slash_aggregator",
      inputs,
      privateKey: env.PK_SLASHER,
      privateFee: false,
      priorityFee: env.FEE, // Utilisation de env.FEE
    },
    "slash_aggregator"
  );
}

// =====================================================
//  PIPELINE PRINCIPALE DE SLASHING
// =====================================================

/**
 * Exécute l'action de slashing configurée (provider ou aggregator).
 * @returns {Promise<void>} Rien si succès, lève une erreur sinon.
 * @throws {Error} Si une étape critique échoue.
 */
export async function runSlash(): Promise<void> {
  const env = getSlashEnv();
  const feedIdField = `${env.FEED_ID}field`;

  console.log(""); // Saut de ligne
  console.log("--- Configuration du Slashing ---");
  console.log("Endpoint Explorateur:", env.EXPLORER_ENDPOINT);
  console.log("Endpoint RPC       :", env.RPC_ENDPOINT);
  console.log("Programme agrégation:", env.AGGREGATE_PROGRAM_ID);
  console.log("Feed ID (Aleo)    :", feedIdField);
  console.log("Action de Slashing :", env.SLASH_ACTION);
  if (env.SLASH_ACTION === "provider") {
    console.log("Provider à Slasher :", env.PROVIDER_TO_SLASH_ADDRESS);
  }
  console.log("Adresse Slasheur   :", env.ADDR_SLASHER);
  console.log("Frais              :", env.FEE);
  console.log("--------------------------------");
  console.log(""); // Saut de ligne

  const account = new Account({ privateKey: env.PK_SLASHER as PrivateKey });
  const keyProvider = new AleoKeyProvider();
  // Utilisation de AleoNetworkClient pour recordProvider comme dans les autres scripts
  const networkClient = new AleoNetworkClient(env.EXPLORER_ENDPOINT);
  const recordProvider = new NetworkRecordProvider(account, networkClient);

  const pm = new ProgramManager(env.RPC_ENDPOINT, keyProvider, recordProvider);
  pm.setHost(env.EXPLORER_ENDPOINT); // Assurez-vous que ProgramManager utilise aussi l'endpoint pour certaines opérations
  pm.setAccount(account);

  let txId: string;

  try {
    if (env.SLASH_ACTION === "provider") {
      if (!env.PROVIDER_TO_SLASH_ADDRESS) {
        // Cette vérification est déjà dans getSlashEnv, mais redondance par sécurité.
        throw new Error(
          "L'adresse du provider à slasher est requise pour cette action."
        );
      }
      txId = await slashProvider(
        pm,
        env,
        feedIdField,
        env.PROVIDER_TO_SLASH_ADDRESS
      );
    } else if (env.SLASH_ACTION === "aggregator") {
      txId = await slashAggregator(pm, env, feedIdField);
    } else {
      // Cette condition ne devrait jamais être atteinte grâce à getSlashEnv
      throw new Error("Action de slashing inconnue.");
    }

    console.log("⏳ En attente de confirmation de la transaction...");
    const confirmation = await waitForConfirmationWithTimeout(
      txId,
      env.EXPLORER_ENDPOINT
    );
    console.log(
      `🎉 Transaction de Slashing ${txId} confirmée avec statut: ${confirmation.status}`
    );
  } catch (err) {
    console.error("❌ Erreur durant le processus de slashing:", err);
    throw err; // Propage l'erreur pour traitement par le point d'entrée
  }
}

// =====================================================
//  POINT D'ENTRÉE SCRIPT
// =====================================================

async function main() {
  try {
    await runSlash();
    console.log("✅ Processus de slashing terminé avec succès.");
  } catch (err) {
    // L'erreur est déjà logguée dans runSlash ou les fonctions appelées
    console.error("💀 Échec du processus de slashing.");
    process.exit(1);
  }
}

main();
