import "dotenv/config";
import fetch from "node-fetch";
import { parseUnits } from "ethers";
import {
  Account,
  AleoNetworkClient,
  ProgramManager,
  AleoKeyProvider,
  NetworkRecordProvider,
  PrivateKey,
} from "@provablehq/sdk";
import { parseNumberEnv } from "../utils/envUtils";
import { median } from "../utils/mathUtils";
import {
  executeOnChain,
  waitForConfirmationWithTimeout,
} from "../utils/aleoUtils";

// =====================================================
//  TYPES ET CONSTANTES DU MODULE
// =====================================================

interface CoinGeckoResponse {
  aleo: { usd: number };
}
interface CoinMarketCapQuote {
  price: number;
}
interface CoinMarketCapData {
  ALEO: { quote: { USD: CoinMarketCapQuote } };
}
interface CoinMarketCapResponse {
  data: CoinMarketCapData;
  status: object;
}
interface CoinStatsResponse {
  price: number;
  [key: string]: any;
}

export interface SubmitEnv {
  PK_PROVIDER: string;
  ADDR_PROVIDER: string;
  EXPLORER_ENDPOINT: string;
  RPC_ENDPOINT: string;
  STAKE_RECORD_ID: string;
  INTERVAL: number;
  MARGIN: number;
  FEE: number;
  SUBMIT_PROGRAM_ID: string;
  CMC_API_KEY: string;
  CS_API_KEY: string;
}

// =====================================================
//  OUTILS DE PARSING ENV ET CONFIGURATION
// =====================================================

/**
 * Récupère et valide toutes les variables d'environnement nécessaires à la soumission.
 */
export function getSubmitEnv(): SubmitEnv {
  const {
    PK_PROVIDER,
    ADDR_PROVIDER,
    EXPLORER_ENDPOINT,
    RPC_ENDPOINT,
    STAKE_RECORD_ID,
    INTERVAL,
    MARGIN,
    FEE,
    SUBMIT_PROGRAM_ID,
    CMC_API_KEY,
    CS_API_KEY,
  } = process.env;
  const missing = [
    "PK_PROVIDER",
    "ADDR_PROVIDER",
    "EXPLORER_ENDPOINT",
    "RPC_ENDPOINT",
    "STAKE_RECORD_ID",
    "INTERVAL",
    "MARGIN",
    "FEE",
    "SUBMIT_PROGRAM_ID",
    "CMC_API_KEY",
    "CS_API_KEY",
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
    INTERVAL: parseNumberEnv("INTERVAL"),
    MARGIN: parseNumberEnv("MARGIN"),
    FEE: parseNumberEnv("FEE"),
    SUBMIT_PROGRAM_ID: SUBMIT_PROGRAM_ID!,
    CMC_API_KEY: CMC_API_KEY!,
    CS_API_KEY: CS_API_KEY!,
  };
}

// =====================================================
//  RÉCUPÉRATION DES PRIX ON-CHAIN
// =====================================================

/**
 * Récupère le prix ALEO/USD depuis plusieurs API et retourne la médiane (u128 string).
 * @returns {Promise<string>} Prix médian sous forme de string
 * @throws {Error} Si aucun prix n'est récupéré
 */
export async function fetchOnChainPrice(env: SubmitEnv): Promise<string> {
  const CG_URL =
    "https://api.coingecko.com/api/v3/simple/price?ids=aleo&vs_currencies=usd";
  const CMC_URL =
    "https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=ALEO";
  const CS_URL = "https://openapiv1.coinstats.app/coins/aleo";
  const prices: bigint[] = [];
  // 1) CoinGecko
  try {
    const cgRes = await fetch(CG_URL, {
      headers: { "X-CMC_PRO_API_KEY": env.CMC_API_KEY },
    });
    if (cgRes.ok) {
      const cgJson = (await cgRes.json()) as CoinGeckoResponse;
      if (cgJson?.aleo?.usd) {
        const cgPrice = cgJson.aleo.usd;
        prices.push(parseUnits(cgPrice.toString(), 18));
        console.log("✅ CoinGecko price fetched:", cgPrice);
      } else {
        console.warn("⚠️ Unexpected CoinGecko response:", cgJson);
      }
    } else {
      const body = await cgRes.text();
      console.warn(`⚠️ CoinGecko HTTP ${cgRes.status}: ${body}`);
    }
  } catch (err: any) {
    console.warn("⚠️ Error fetching CoinGecko price:", err.message);
  }
  // 2) CoinMarketCap
  try {
    const cmcRes = await fetch(CMC_URL, {
      headers: { "X-CMC_PRO_API_KEY": env.CMC_API_KEY },
    });
    if (cmcRes.ok) {
      const cmcJson = (await cmcRes.json()) as CoinMarketCapResponse;
      const cmcPrice = cmcJson?.data?.ALEO?.quote?.USD?.price;
      if (cmcPrice) {
        prices.push(parseUnits(cmcPrice.toString(), 18));
        console.log("✅ CoinMarketCap price fetched:", cmcPrice);
      } else {
        console.warn("⚠️ Unexpected CoinMarketCap response:", cmcJson);
      }
    } else {
      const body = await cmcRes.text();
      console.warn(`⚠️ CoinMarketCap HTTP ${cmcRes.status}: ${body}`);
    }
  } catch (err: any) {
    console.warn("⚠️ Error fetching CoinMarketCap price:", err.message);
  }
  // 3) Coinstats
  try {
    const csRes = await fetch(CS_URL, {
      headers: { "X-API-KEY": env.CS_API_KEY, accept: "application/json" },
    });
    if (csRes.ok) {
      const csJson = (await csRes.json()) as CoinStatsResponse;
      const csPrice = csJson?.price;
      if (csPrice) {
        prices.push(parseUnits(csPrice.toString(), 18));
        console.log("✅ Coinstat price fetched:", csPrice);
      } else {
        console.warn("⚠️ Unexpected Coinstat response:", csJson);
      }
    } else {
      const body = await csRes.text();
      console.warn(`⚠️ Coinstat HTTP ${csRes.status}: ${body}`);
    }
  } catch (err: any) {
    console.warn("⚠️ Error fetching Coinstat price:", err.message);
  }
  if (prices.length === 0) {
    throw new Error("Aucun prix n'a pu être récupéré depuis les providers.");
  }
  // Utilisation de la médiane pour plus de robustesse
  const medianPrice = median(prices);
  const humanReadable = Number(medianPrice) / 1e18;
  console.log(`💰 Prix médian calculé : ${humanReadable} ALEO`);
  return medianPrice.toString();
}

// =====================================================
//  LOGIQUE DE SOUMISSION PRINCIPALE
// =====================================================

/**
 * Pipeline principale : récupère le prix, le soumet on-chain, attend la confirmation.
 * @returns {Promise<void>} Rien si succès, lève une erreur sinon
 * @throws {Error} Si une étape critique échoue
 */
export async function runSubmit(): Promise<void> {
  const env = getSubmitEnv();
  const RECORD_ID_FIELD = `${env.STAKE_RECORD_ID}field`;
  const explorerClient = new AleoNetworkClient(env.EXPLORER_ENDPOINT);
  const account = new Account({ privateKey: env.PK_PROVIDER as PrivateKey });
  const keyProvider = new AleoKeyProvider();
  const recordProvider = new NetworkRecordProvider(account, explorerClient);
  const pm = new ProgramManager(env.RPC_ENDPOINT, keyProvider, recordProvider);
  pm.setHost(env.EXPLORER_ENDPOINT);
  pm.setAccount(account);

  // Récupération du prix médian
  const priceU128 = (await fetchOnChainPrice(env)) + "u128";
  console.log("Program ID:", env.SUBMIT_PROGRAM_ID);
  console.log("Record ID:", RECORD_ID_FIELD);
  console.log("Price:", priceU128);
  console.log("Provider:", env.ADDR_PROVIDER);

  // Soumission on-chain
  let txId: string;
  try {
    txId = await executeOnChain(
      pm,
      {
        programName: env.SUBMIT_PROGRAM_ID,
        functionName: "submit_price",
        priorityFee: 0,
        privateKey: account.privateKey(),
        privateFee: false,
        inputs: [RECORD_ID_FIELD, priceU128, env.ADDR_PROVIDER],
      },
      "submit_price"
    );
  } catch (err) {
    console.error("❌ Erreur durant execute() :", err);
    throw err;
  }

  // Confirmation transactionnelle avec timeout global
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
    await runSubmit();
  } catch (err) {
    console.error("Erreur fatale :", err);
    process.exit(1);
  }
}

main();
