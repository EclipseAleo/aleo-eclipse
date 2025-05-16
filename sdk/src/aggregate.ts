import "dotenv/config";
import {
  Account,
  AleoNetworkClient,
  ProgramManager,
  AleoKeyProvider,
  NetworkRecordProvider,
  PrivateKey,
} from "@provablehq/sdk";
import { readAleoMapping, executeOnChain } from "../utils/aleoUtils";
import { median } from "../utils/mathUtils";
import { parseNumberEnv } from "../utils/envUtils";
// =====================================================
//  TYPES ET CONSTANTES DU MODULE
// =====================================================

export type ProviderPrices = Record<string, bigint>;

export interface AggregateEnv {
  PK_PROVIDER: string;
  ADDR_PROVIDER: string;
  EXPLORER_ENDPOINT: string;
  RPC_ENDPOINT: string;
  STAKE_RECORD_ID: string;
  INTERVAL: number;
  MARGIN: number;
  FEE: number;
  AGGREGATE_PROGRAM_ID: string;
  SUBMIT_PROGRAM_ID: string;
  STAKE_PROGRAM_ID: string;
}

// =====================================================
//  OUTILS DE PARSING ENV ET CONFIGURATION
// =====================================================

/**
 * Récupère et valide toutes les variables d'environnement nécessaires à l'agrégation.
 * @returns {AggregateEnv} Un objet contenant toutes les variables d'environnement typées et validées.
 * @throws {Error} Si une variable obligatoire est manquante ou invalide.
 */
export function getEnv(): AggregateEnv {
  const {
    PK_PROVIDER,
    ADDR_PROVIDER,
    EXPLORER_ENDPOINT,
    RPC_ENDPOINT,
    STAKE_RECORD_ID,
    AGGREGATE_PROGRAM_ID,
    SUBMIT_PROGRAM_ID,
    STAKE_PROGRAM_ID,
  } = process.env;

  if (
    !PK_PROVIDER ||
    !ADDR_PROVIDER ||
    !EXPLORER_ENDPOINT ||
    !RPC_ENDPOINT ||
    !STAKE_RECORD_ID ||
    !AGGREGATE_PROGRAM_ID ||
    !SUBMIT_PROGRAM_ID ||
    !STAKE_PROGRAM_ID
  ) {
    throw new Error("Variables d'environnement manquantes");
  }
  return {
    PK_PROVIDER,
    ADDR_PROVIDER,
    EXPLORER_ENDPOINT,
    RPC_ENDPOINT,
    STAKE_RECORD_ID,
    INTERVAL: parseNumberEnv("INTERVAL"),
    MARGIN: parseNumberEnv("MARGIN"),
    FEE: parseNumberEnv("FEE"),
    AGGREGATE_PROGRAM_ID,
    SUBMIT_PROGRAM_ID,
    STAKE_PROGRAM_ID,
  };
}

// =====================================================
//  ACCÈS AU RÉSEAU ALEO (LECTURE DES PROVIDERS ET PRIX)
// =====================================================

/**
 * Récupère le nombre de providers actifs depuis le mapping du smart contract.
 * @param explorerClient Client réseau Aleo
 * @param stakeProgramId Identifiant du programme de staking
 * @param recordIdField Champ record utilisé pour l'accès mapping
 * @returns {Promise<number>} Le nombre de providers actifs
 * @throws {Error} Si aucun provider n'est trouvé ou si la valeur n'est pas un nombre
 */
export async function getProviderCount(
  explorerClient: AleoNetworkClient,
  stakeProgramId: string,
  recordIdField: string
): Promise<number> {
  const val = await readAleoMapping(
    explorerClient,
    stakeProgramId,
    "provider_count",
    [recordIdField]
  );
  const count = Number(val);
  if (isNaN(count) || count === 0) throw new Error("Aucun provider actif");
  return count;
}

/**
 * Récupère les prix soumis par chaque provider (parallélisé).
 * @param explorerClient Client réseau Aleo
 * @param stakeProgramId Identifiant du programme de staking
 * @param submitProgramId Identifiant du programme de soumission
 * @param recordIdField Champ record utilisé pour l'accès mapping
 * @param providerCount Nombre de providers à interroger
 * @returns {Promise<ProviderPrices>} Un objet associant chaque provider à son prix
 */
export async function getProviderPrices(
  explorerClient: AleoNetworkClient,
  stakeProgramId: string,
  submitProgramId: string,
  recordIdField: string,
  providerCount: number
): Promise<ProviderPrices> {
  const providerPrices: ProviderPrices = {};
  // Parallélisation des lectures
  const tasks = Array.from({ length: providerCount }, (_, i) =>
    (async () => {
      try {
        const providerAddr = await readAleoMapping(
          explorerClient,
          stakeProgramId,
          "provider_list",
          [recordIdField, i.toString()]
        );
        const price = await readAleoMapping(
          explorerClient,
          submitProgramId,
          "temp_price",
          [recordIdField + providerAddr]
        );
        return { providerAddr, price: BigInt(price), index: i };
      } catch (err) {
        return { error: err, index: i };
      }
    })()
  );
  const results = await Promise.allSettled(tasks);
  for (const result of results) {
    if (
      result.status === "fulfilled" &&
      result.value &&
      !("error" in result.value)
    ) {
      const { providerAddr, price } = result.value;
      console.log("🔎 Prix du provider", providerAddr, ":", price.toString());
      providerPrices[providerAddr] = price;
    } else if (
      result.status === "fulfilled" &&
      result.value &&
      "error" in result.value
    ) {
      console.warn(
        `Provider ${result.value.index}: erreur lors de la lecture du prix`,
        result.value.error
      );
    } else if (result.status === "rejected") {
      console.warn(
        "Erreur inattendue lors de la lecture d'un provider :",
        result.reason
      );
    }
  }
  return providerPrices;
}

// =====================================================
//  INTERACTIONS ON-CHAIN (PROPOSE & FINALIZE)
// =====================================================

/**
 * Propose la médiane calculée on-chain.
 * @param pm ProgramManager
 * @param aggregateProgramId Identifiant du programme d'agrégation
 * @param recordIdField Champ record utilisé pour l'accès mapping
 * @param medianPrice Valeur médiane à proposer
 * @param addrProvider Adresse du provider
 * @param privateKey Clé privée du provider
 * @param fee Les frais de priorité à appliquer
 * @returns {Promise<string>} L'identifiant de la transaction
 * @throws {Error} En cas d'échec de la transaction
 */
export async function proposeMedian(
  pm: ProgramManager,
  aggregateProgramId: string,
  recordIdField: string,
  medianPrice: bigint,
  addrProvider: string,
  privateKey: string,
  fee: number
): Promise<string> {
  return executeOnChain(
    pm,
    {
      programName: aggregateProgramId,
      functionName: "propose",
      inputs: [recordIdField, medianPrice.toString() + "u128", addrProvider],
      privateKey,
      privateFee: false,
      priorityFee: fee,
    },
    "propose"
  );
}

/**
 * Finalise l'agrégation on-chain après la période de challenge.
 * @param pm ProgramManager
 * @param aggregateProgramId Identifiant du programme d'agrégation
 * @param recordIdField Champ record utilisé pour l'accès mapping
 * @param addrProvider Adresse du provider
 * @param privateKey Clé privée du provider
 * @param fee Les frais de priorité à appliquer
 * @returns {Promise<string>} L'identifiant de la transaction
 * @throws {Error} En cas d'échec de la transaction
 */
export async function finalizeAggregate(
  pm: ProgramManager,
  aggregateProgramId: string,
  recordIdField: string,
  addrProvider: string,
  privateKey: string,
  fee: number
): Promise<string> {
  return executeOnChain(
    pm,
    {
      programName: aggregateProgramId,
      functionName: "finalize_aggregate",
      inputs: [recordIdField, addrProvider],
      privateKey,
      privateFee: false,
      priorityFee: fee,
    },
    "finalize_aggregate"
  );
}

// =====================================================
//  PIPELINE PRINCIPALE D'AGRÉGATION
// =====================================================

/**
 * Pipeline principale : lit les prix, calcule la médiane, propose et finalise on-chain.
 * @returns {Promise<void>} Rien si succès, lève une erreur sinon
 * @throws {Error} Si une étape critique échoue
 */
export async function runAggregate(): Promise<void> {
  const env = getEnv();
  // RECORD_ID_FIELD correspond au champ "field" du record de staking dans le programme Aleo.
  // C'est la convention utilisée dans les mappings du smart contract.
  const RECORD_ID_FIELD = `${env.STAKE_RECORD_ID}field`;

  const explorerClient = new AleoNetworkClient(env.EXPLORER_ENDPOINT);
  const account = new Account({ privateKey: env.PK_PROVIDER as PrivateKey });
  const keyProvider = new AleoKeyProvider();
  const recordProvider = new NetworkRecordProvider(account, explorerClient);
  const pm = new ProgramManager(env.RPC_ENDPOINT, keyProvider, recordProvider);
  pm.setHost(env.EXPLORER_ENDPOINT);
  pm.setAccount(account);

  const providerCount = await getProviderCount(
    explorerClient,
    env.STAKE_PROGRAM_ID,
    RECORD_ID_FIELD
  );
  console.log("🔎 Nombre de providers trouvés :", providerCount, "👥");

  const providerPrices = await getProviderPrices(
    explorerClient,
    env.STAKE_PROGRAM_ID,
    env.SUBMIT_PROGRAM_ID,
    RECORD_ID_FIELD,
    providerCount
  );
  const prices = Object.values(providerPrices);
  if (prices.length === 0) {
    throw new Error("Aucun prix trouvé pour cette fenêtre d'agrégation");
  }

  const medianPrice = median(prices);
  console.log(`Médiane calculée: ${medianPrice.toString()}`);

  try {
    await proposeMedian(
      pm,
      env.AGGREGATE_PROGRAM_ID,
      RECORD_ID_FIELD,
      medianPrice,
      env.ADDR_PROVIDER,
      account.privateKey(),
      env.FEE
    );
  } catch (err) {
    console.error("Erreur lors de la proposition de la médiane:", err);
    throw err;
  }

  try {
    await finalizeAggregate(
      pm,
      env.AGGREGATE_PROGRAM_ID,
      RECORD_ID_FIELD,
      env.ADDR_PROVIDER,
      account.privateKey(),
      env.FEE
    );
  } catch (err) {
    console.error("Erreur lors de la finalisation de l'agrégation:", err);
    throw err;
  }
}

// =====================================================
//  POINT D'ENTRÉE SCRIPT
// =====================================================

async function main() {
  try {
    await runAggregate();
  } catch (err) {
    console.error("Erreur fatale :", err);
    process.exit(1);
  }
}

main();
