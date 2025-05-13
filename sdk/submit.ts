import "dotenv/config";
import fetch, { Response as FetchResponse } from "node-fetch";
import { parseUnits } from "ethers";
import {
  Account,
  AleoNetworkClient,
  ProgramManager,
  AleoKeyProvider,
  NetworkRecordProvider,
  PrivateKey, // S'assurer que ce type est bien exporté par le SDK
} from "@provablehq/sdk";

// Interfaces pour les réponses des API de prix
interface CoinGeckoResponse {
  aleo: { usd: number };
}

interface CoinMarketCapQuote {
  price: number;
}

interface CoinMarketCapData {
  ALEO: {
    quote: { USD: CoinMarketCapQuote };
  };
}

interface CoinMarketCapResponse {
  data: CoinMarketCapData;
  status: object;
}

// Définition de l'interface pour la réponse de CoinStats selon le schéma fourni
interface CoinStatsResponse {
  id: string;
  icon: string;
  name: string;
  symbol: string;
  rank: number;
  price: number;
  priceBtc: number;
  volume: number;
  marketCap: number;
  availableSupply: number;
  totalSupply: number;
  fullyDilutedValuation: number;
  priceChange1h: number;
  priceChange1d: number;
  priceChange1w: number;
  websiteUrl: string;
  redditUrl: string;
  twitterUrl: string;
  contractAddress: string;
  decimals: number;
  explorers: string[];
  liquidityScore: number;
  volatilityScore: number;
  marketCapScore: number;
  riskScore: number;
  avgChange: number;
}

interface TransactionConfirmationStatus {
  status: string;
}

async function fetchOnChainPrice(): Promise<string> {
  // Attempt to fetch the price from as many providers as possible, allow HTTP errors
  const prices: bigint[] = [];

  // 1) CoinGecko
  try {
    const cgRes = await fetch(
      "https://api.coingecko.com/api/v3/simple/price?ids=aleo&vs_currencies=usd",
      process.env.CG_API_KEY ? { headers: { "X-CMC_PRO_API_KEY": process.env.CG_API_KEY } } : {}
    );
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
    const cmcRes = await fetch(
      "https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=ALEO",
      { headers: { "X-CMC_PRO_API_KEY": process.env.CMC_API_KEY! } }
    );
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

  // 3) Coinstat
  try {
    const csRes = await fetch(
      "https://openapiv1.coinstats.app/coins/aleo",
      {
        headers: { "X-API-KEY": process.env.CS_API_KEY!,
                   "accept": "application/json" }
      }
    );
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

  // Add more providers if needed

  if (prices.length === 0) {
    throw new Error("No price could be fetched from any provider.");
  }

  // Arithmetic mean of all fetched prices
  const sum = prices.reduce((acc, v) => acc + v, 0n);
  const average = sum / BigInt(prices.length);


  const humanReadableAverage = Number(average) / 1e18;
  console.log(`💰 Prix moyen calculé : ${humanReadableAverage} ALEO`);
  return average.toString();
}

async function getCurrentBlockHeight(): Promise<number> {
  const url = process.env.EXPLORER_ENDPOINT + `/` + process.env.NETWORK + `/latest/height`;
  const res: FetchResponse = await fetch(url);
  if (!res.ok) throw new Error(`Height HTTP ${res.status}`);
  const jsonResponse = (await res.json()) as any;
  return Number(jsonResponse);
}

async function getTransactionConfirmationStatus(
  txId: string
): Promise<TransactionConfirmationStatus> {
  const url = process.env.EXPLORER_ENDPOINT + `/` + process.env.NETWORK + `/transaction/confirmed/${txId}`;
  const res: FetchResponse = await fetch(url, {
    headers: { Accept: "application/json" },
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`HTTP ${res.status}: ${body}`);
  }
  const data = (await res.json()) as TransactionConfirmationStatus;
  console.log("🔍 Confirmation status:", data.status);
  return data;
}

async function main() {
  const {
    PK_PROVIDER,
    ADDR_PROVIDER,
    RPC_ENDPOINT,
    STAKE_RECORD_ID,
    INTERVAL,
    MARGIN,
    FEE,
  } = process.env;

  const requiredEnvVars: string[] = [
    "PK_PROVIDER",
    "ADDR_PROVIDER",
    "RPC_ENDPOINT",
    "STAKE_RECORD_ID",
    "INTERVAL",
    "MARGIN",
    "FEE",
    "CMC_API_KEY",
    "CS_API_KEY",
  ];

  const missing = requiredEnvVars.filter((env) => !process.env[env]);

  if (missing.length > 0) {
    console.error(`Missing env var(s): ${missing.join(", ")}`);
    process.exit(1);
  }

  // Assertions pour TypeScript après vérification
  const pkProvider = PK_PROVIDER!;
  const addrProvider = ADDR_PROVIDER!;
  const rpcEndpoint = RPC_ENDPOINT!;
  const stakeRecordId = STAKE_RECORD_ID!;
  const interval = Number(INTERVAL!);
  const margin = Number(MARGIN!);
  const fee = FEE!; // On l'utilise ou pas ?
  const PROGRAM_ID = "eclipse_oracle_submit_2.aleo";
  const RECORD_ID_FIELD = `${stakeRecordId}field`;

  const explorerClient = new AleoNetworkClient(process.env.EXPLORER_ENDPOINT!);
  const account = new Account({ privateKey: pkProvider as PrivateKey });
  const keyProvider = new AleoKeyProvider();
  const recordProvider = new NetworkRecordProvider(account, explorerClient);
  const pm = new ProgramManager(rpcEndpoint, keyProvider, recordProvider);
  pm.setHost(process.env.EXPLORER_ENDPOINT!);
  pm.setAccount(account);

  let executedWindow = -1;

  while (true) {
    try {
      const height = await getCurrentBlockHeight();
      const windowVal = Math.floor(height / interval);
      const pos = height % interval;
      console.log(`⛓ block ${height}, window ${windowVal}, pos ${pos}`);

      if (windowVal > executedWindow) {
        if (pos <= interval - margin) {
          console.log("→ within execution window, submitting price…");
          const priceU128 = (await fetchOnChainPrice()) + "u128";
          console.log(
            "Program ID:",
            PROGRAM_ID, + "\n"+
            "Record ID:",
            RECORD_ID_FIELD, + "\n"+
            "Price:",
            priceU128, + "\n" +
            "Provider:",
            addrProvider
            // 'Private Key:', account.privateKey() // Éviter de logger la clé privée en production
          );
          const txId: string = await pm.execute({
            programName: PROGRAM_ID,
            functionName: "submit_price",
            inputs: [RECORD_ID_FIELD, priceU128, addrProvider],
            privateKey: account.privateKey(),
            privateFee: false,
            priorityFee: 0,
            // fees ?
          });
          console.log("✅ submitted txId:", txId);
          console.log("⏳ En attente de confirmation (on va ignorer les 500)…");

          let confirm: TransactionConfirmationStatus | null = null;
          let cpt = 0;
          while (true) {
            cpt += 1;
            try {
              const data = await getTransactionConfirmationStatus(txId);
              console.log(`🔍 status (tentative ${cpt}):`, data.status);
              if (data.status === "accepted") {
                confirm = data;
                break;
              } else if (data.status === "rejected") {
                console.error(`❌ Transaction ${txId} rejetée !`);
                break;
              } else if (cpt > 50) {
                console.error(`❌ Transaction ${txId} non confirmée après 50 tentatives !`);
                break;
              }
            } catch (err: any) {
              console.warn(
                `   ⚠️ Erreur confirmation (tentative ${cpt}):`,
                err.message
              );
            }
            await new Promise((resolve) => setTimeout(resolve, 10_000)); // 10s
          }

          console.log(`🎉 Transaction ${txId} acceptée !`);
          executedWindow = windowVal;
        } else {
          console.error(`❌ missed execution window for ${windowVal}`);
          executedWindow = windowVal;
        }
      }
    } catch (err: any) {
      console.error("⚠️ loop error:", err);
    }

    await new Promise((resolve) => setTimeout(resolve, 600_000)); // 10 min
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
