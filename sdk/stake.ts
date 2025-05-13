import "dotenv/config";
import fetch from "node-fetch";
import {
  Account,
  AleoNetworkClient,
  ProgramManager,
  AleoKeyProvider,
  NetworkRecordProvider,
  PrivateKey,
} from "@provablehq/sdk";

// Définition d'un type pour la réponse de confirmation de transaction
interface TransactionConfirmationStatus {
  status: string;
}

async function getTransactionConfirmationStatus(
  txId: string
): Promise<TransactionConfirmationStatus> {
  const url = process.env.EXPLORER_ENDPOINT + `/` + process.env.NETWORK + `/transaction/confirmed/${txId}`;
  const res = await fetch(url, { headers: { Accept: "application/json" } });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`HTTP ${res.status}: ${body}`);
  }
  const data = (await res.json()) as TransactionConfirmationStatus;
  console.log("🔍 Confirmation status:", data.status);
  return data;
}

(async () => {
  console.log("▶️  Démarrage de stake.ts");

  const {
    PK_PROVIDER,
    ADDR_PROVIDER,
    EXPLORER_ENDPOINT,
    RPC_ENDPOINT,
    STAKE_RECORD_ID,
    STAKE_AMOUNT,
    FEE,
  } = process.env;

  const STAKE_PROGRAM_ID = "eclipse_oracle_staking_2.aleo";

  const requiredEnvVars: string[] = [
    "PK_PROVIDER",
    "ADDR_PROVIDER",
    "EXPLORER_ENDPOINT",
    "RPC_ENDPOINT",
    "STAKE_RECORD_ID",
    "STAKE_AMOUNT",
    "FEE",
  ];
  const missing: string[] = [];
  requiredEnvVars.forEach((k) => {
    if (!process.env[k]) {
      missing.push(k);
    }
  });

  if (missing.length) {
    console.error("❌ Variables manquantes dans .env:", missing.join(", "));
    process.exit(1);
  }

  const pkProvider = PK_PROVIDER!;
  const addrProvider = ADDR_PROVIDER!;
  const explorerEndpoint = EXPLORER_ENDPOINT!;
  const rpcEndpoint = RPC_ENDPOINT!;
  const stakeRecordId = STAKE_RECORD_ID!;
  const stakeAmount = STAKE_AMOUNT!;
  const fee = FEE!;

  console.log("\n--- Config ---");
  console.log("Explorer endpoint:", explorerEndpoint);
  console.log("RPC endpoint     :", rpcEndpoint);
  console.log("Program ID       :", STAKE_PROGRAM_ID);
  console.log("Record ID        :", stakeRecordId);
  console.log("Amount / Fee     :", stakeAmount, "/", fee);
  console.log("--------------------------------\n");

  const explorerClient = new AleoNetworkClient(explorerEndpoint);
  console.log("explorerClient.host =", explorerClient.host);

  const account = new Account({ privateKey: pkProvider as PrivateKey });
  const keyProvider = new AleoKeyProvider();
  const recordProvider = new NetworkRecordProvider(account, explorerClient);
  const programManager = new ProgramManager(
    rpcEndpoint,
    keyProvider,
    recordProvider
  );

  programManager.setHost(explorerEndpoint);
  programManager.setAccount(account);
  console.log("programManager.rpcUrl =", rpcEndpoint);
  console.log("programManager.host   =", programManager.host, "\n");

  const inputs: string[] = [`${stakeRecordId}field`, stakeAmount, addrProvider];

  console.log("📤 Diffusion de « stake » avec :");
  console.log("  programName:", STAKE_PROGRAM_ID);
  console.log("  inputs     :", inputs);
  console.log("  fee        :", fee);

  try {
    const txId: string = await programManager.execute({
      programName: STAKE_PROGRAM_ID,
      functionName: "stake",
      inputs,
      privateKey: account.privateKey(),
      privateFee: false,
      priorityFee: 0
    });
    console.log("✅ Transaction envoyée ! ID:", txId);
    console.log("⏳ En attente de confirmation…");

    let confirmation: TransactionConfirmationStatus | null = null;
    let attempt = 0;
    do {
      attempt += 1;
      console.log(`Polling #${attempt}…`);
      try {
        confirmation = await getTransactionConfirmationStatus(txId);
      } catch (err: any) {
        console.warn(
          `   ⚠️ Erreur fetching confirmation status (tentative ${attempt}):`,
          err.message
        );
        confirmation = null;
      }

      if (!confirmation || confirmation.status !== "accepted") {
        console.log("   …en attente 10 s avant le prochain essai");
        await new Promise((r) => setTimeout(r, 10_000));
      }
    } while (!confirmation || confirmation.status !== "accepted");

    console.log(`🎉 Transaction ${txId} status: ${confirmation.status}`);
  } catch (err: any) {
    console.error("❌ Erreur durant execute():", err.message);
    console.error(err.stack);
    if (err.response) {
      console.error("- response.status:", err.response.status);
      console.error("- response.data  :", err.response.data);
    }
  }
})();
