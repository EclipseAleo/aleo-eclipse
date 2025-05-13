// ===============================
//  ALEO UTILS — Fonctions génériques
// ===============================

import { AleoNetworkClient, ProgramManager } from "@provablehq/sdk";
import fetch from "node-fetch";

// ===============================
//  Lecture des mappings Aleo
// ===============================

/**
 * Lit une valeur de mapping sur le réseau Aleo.
 * @param client Le client réseau Aleo
 * @param programId L'identifiant du programme Aleo
 * @param mappingName Le nom du mapping à lire
 * @param args Les arguments du mapping
 * @returns La valeur lue (string)
 */
export async function readAleoMapping(
  client: AleoNetworkClient,
  programId: string,
  mappingName: string,
  args: string[]
): Promise<string> {
  return client.getProgramMappingValue(programId, mappingName, args);
}

// ===============================
//  Exécution on-chain avec logs et gestion d'erreur
// ===============================

/**
 * Exécute une fonction on-chain via ProgramManager avec logs et gestion d'erreur.
 * @param pm ProgramManager
 * @param params Paramètres pour pm.execute
 * @param actionLabel Libellé pour le log (ex: 'propose', 'finalize')
 * @returns L'identifiant de la transaction
 * @throws En cas d'échec de la transaction
 */
export async function executeOnChain(
  pm: ProgramManager,
  params: Parameters<ProgramManager["execute"]>[0],
  actionLabel: string
): Promise<string> {
  try {
    const txId = await pm.execute(params);
    console.log(`✅ ${actionLabel} envoyée, txId:`, txId);
    return txId;
  } catch (err) {
    console.error(`Erreur lors de l'action ${actionLabel} :`, err);
    throw err;
  }
}


// ===============================
//  Confirmation transactionnelle Aleo
// ===============================

/**
 * Récupère le statut de confirmation d'une transaction Aleo.
 * @param txId Identifiant de la transaction
 * @param explorerEndpoint Endpoint de l'explorer Aleo
 * @returns {Promise<{status: string}>} Statut de confirmation
 * @throws {Error} En cas d'erreur HTTP ou de parsing
 */
export async function getTransactionConfirmationStatus(
  txId: string,
  explorerEndpoint: string
): Promise<{ status: string }> {
  const url = `${explorerEndpoint}/v1/testnet/transaction/confirmed/${txId}`;
  const res = await fetch(url, { headers: { Accept: "application/json" } });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`HTTP ${res.status}: ${body}`);
  }
  const data = (await res.json()) as { status: string };
  console.log("🔍 Confirmation status:", data.status);
  return data;
}

/**
 * Attend la confirmation d'une transaction Aleo avec timeout global.
 * @param txId Identifiant de la transaction
 * @param explorerEndpoint Endpoint de l'explorer Aleo
 * @param timeoutMs Délai maximal en ms (défaut : 10 min)
 * @returns {Promise<{status: string}>}
 * @throws {Error} Si la confirmation n'arrive pas dans le délai imparti
 */
export async function waitForConfirmationWithTimeout(
  txId: string,
  explorerEndpoint: string,
  timeoutMs = 10 * 60 * 1000 // 10 minutes
): Promise<{ status: string }> {
  return Promise.race([
    (async () => {
      let confirmation: { status: string } | null = null;
      let attempt = 0;
      do {
        attempt += 1;
        console.log(`Polling #${attempt}…`);
        try {
          confirmation = await getTransactionConfirmationStatus(
            txId,
            explorerEndpoint
          );
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
      return confirmation;
    })(),
    new Promise<never>((_, reject) =>
      setTimeout(
        () =>
          reject(new Error("Timeout de confirmation de transaction dépassé")),
        timeoutMs
      )
    ),
  ]);
}
