import 'dotenv/config';
import fetch from 'node-fetch';
import { BigNumber, utils as ethersUtils } from 'ethers';
import {
  Account,
  AleoNetworkClient,
  ProgramManager,
  AleoKeyProvider,
  NetworkRecordProvider,
} from '@provablehq/sdk';

async function fetchOnChainPrice() {
  // 1) CoinGecko
  const cgRes = await fetch(
    'https://api.coingecko.com/api/v3/simple/price?ids=aleo&vs_currencies=usd'
  );
  if (!cgRes.ok) throw new Error(`CG HTTP ${cgRes.status}`);
  const { aleo } = await cgRes.json();
  const cgPrice = aleo.usd;

  // 2) CoinMarketCap
  const cmcRes = await fetch(
    'https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=ALEO',
    { headers: { 'X-CMC_PRO_API_KEY': process.env.CMC_API_KEY } }
  );
  if (!cmcRes.ok) throw new Error(`CMC HTTP ${cmcRes.status}`);
  const cmcJson = await cmcRes.json();
  const cmcPrice = cmcJson.data.ALEO.quote.USD.price;
  
  // Somme des deux
  const bn1 = ethersUtils.parseUnits(cgPrice.toString(), 18);
  const bn2 = ethersUtils.parseUnits(cmcPrice.toString(), 18);
  const avg = bn1.add(bn2).div(BigNumber.from(2));
  return avg.toString();
}

async function getCurrentBlockHeight(explorerRequestEndpoint) {
  const url = `${explorerRequestEndpoint}/latest/height`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Height HTTP ${res.status}`);
  return Number(await res.json());
}

async function getTransactionConfirmationStatus(txId) {
  const url = `https://api.explorer.provable.com/v1/testnet/transaction/confirmed/${txId}`;
  const res = await fetch(url, { headers: { Accept: 'application/json' } });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`HTTP ${res.status}: ${body}`);
  }
  const data = await res.json();
  console.log('🔍 Confirmation status:', data.status);
  return data;
}

async function main() {
  const {
    PK_PROVIDER,
    ADDR_PROVIDER,
    EXPLORER_ENDPOINT,
    RPC_ENDPOINT,
    STAKE_RECORD_ID,
    INTERVAL,
    MARGIN,
    FEE,
    CMC_API_KEY,
  } = process.env;

  const EXPLORER_REQUEST_ENDPOINT = 'https://api.explorer.provable.com/v1/testnet';

  for (const k of [
    'PK_PROVIDER','ADDR_PROVIDER','EXPLORER_ENDPOINT','RPC_ENDPOINT',
    'STAKE_RECORD_ID','INTERVAL','MARGIN','FEE','CMC_API_KEY'
  ]) {
    if (!process.env[k]) {
      console.error(`Missing env var: ${k}`);
      process.exit(1);
    }
  }

  const PROGRAM_ID      = 'eclipse_oracle_submit_2.aleo';
  const RECORD_ID_FIELD = `${STAKE_RECORD_ID}field`;
  const interval = Number(INTERVAL);
  const margin   = Number(MARGIN);

  const explorerClient = new AleoNetworkClient(EXPLORER_ENDPOINT);
  const account        = new Account({ privateKey: PK_PROVIDER });
  const keyProvider    = new AleoKeyProvider();
  const recordProvider = new NetworkRecordProvider(account, explorerClient);
  const pm             = new ProgramManager(RPC_ENDPOINT, keyProvider, recordProvider);
  pm.setHost(EXPLORER_ENDPOINT);
  pm.setAccount(account);

  let executedWindow = -1;

  while (true) {
    try {
      const height = await getCurrentBlockHeight(EXPLORER_REQUEST_ENDPOINT);
      const window = Math.floor(height / interval);
      const pos    = height % interval;
      console.log(`⛓ block ${height}, window ${window}, pos ${pos}`);

      if (window > executedWindow) {
        if (pos <= (interval - margin)) {
          console.log('→ within execution window, submitting price…');
          const priceU128 = (await fetchOnChainPrice()) + 'u128';
          console.log('Program ID:', PROGRAM_ID, 'Record ID:', RECORD_ID_FIELD, 'Price:', priceU128, 'Provider:', ADDR_PROVIDER, 'Private Key:', account.privateKey());
          const txId = await pm.execute({
            programName:  PROGRAM_ID,
            functionName: 'submit_price',
            inputs:       [RECORD_ID_FIELD, priceU128, ADDR_PROVIDER],
            privateKey:   account.privateKey(),
            privateFee:   false,
          });
          console.log('✅ submitted txId:', txId);
          console.log('⏳ En attente de confirmation (on va ignorer les 500)…');
          let confirm = null;
          let cpt = 0;
          while (true) {
            cpt += 1;
            try {
              const data = await getTransactionConfirmationStatus(txId);
              console.log(`🔍 status (tentative ${cpt}):`, data.status);
              if (data.status === 'accepted') {
                confirm = data;
                break;
              }
            } catch (err) {
              console.warn(`   ⚠️ Erreur confirmation (tentative ${cpt}):`, err.message);
            }
            await new Promise(r => setTimeout(r, 10_000));
          }

          console.log(`🎉 Transaction ${txId} acceptée !`);
          executedWindow = window;

        } else {
          console.error(`❌ missed execution window for ${window}`);
          executedWindow = window; 
        }
      }
    } catch (err) {
      console.error('⚠️ loop error:', err);
    }

    await new Promise(r => setTimeout(r, 600_000));
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
