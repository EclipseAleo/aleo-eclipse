import 'dotenv/config';
import {
  Account,
  AleoNetworkClient,
  ProgramManager,
  AleoKeyProvider,
  NetworkRecordProvider,
} from '@provablehq/sdk';

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

(async () => {
  console.log('▶️  Démarrage de stake.js');

  const {
    PK_PROVIDER,
    ADDR_PROVIDER,
    EXPLORER_ENDPOINT,
    RPC_ENDPOINT,
    STAKE_RECORD_ID,
    STAKE_AMOUNT,
    FEE,
  } = process.env;

  const STAKE_PROGRAM_ID = 'eclipse_oracle_staking_2.aleo';

  const missing = [];
  ['PK_PROVIDER','ADDR_PROVIDER','EXPLORER_ENDPOINT','RPC_ENDPOINT','STAKE_RECORD_ID','STAKE_AMOUNT','FEE']
    .forEach(k => !process.env[k] && missing.push(k));
  if (missing.length) {
    console.error('❌ Variables manquantes dans .env:', missing.join(', '));
    process.exit(1);
  }

  console.log('\n--- Config ---');
  console.log('Explorer endpoint:', EXPLORER_ENDPOINT);
  console.log('RPC endpoint     :', RPC_ENDPOINT);
  console.log('Program ID       :', STAKE_PROGRAM_ID);
  console.log('Record ID        :', STAKE_RECORD_ID);
  console.log('Amount / Fee     :', STAKE_AMOUNT, '/', FEE);
  console.log('--------------------------------\n');

  const explorerClient = new AleoNetworkClient(EXPLORER_ENDPOINT);
  console.log('explorerClient.host =', explorerClient.host);

  const account        = new Account({ privateKey: PK_PROVIDER });
  const keyProvider    = new AleoKeyProvider();
  const recordProvider = new NetworkRecordProvider(account, explorerClient);
  const programManager = new ProgramManager(RPC_ENDPOINT, keyProvider, recordProvider);

  programManager.setHost(EXPLORER_ENDPOINT);
  programManager.setAccount(account);
  console.log('programManager.rpcUrl =', RPC_ENDPOINT);
  console.log('programManager.host   =', programManager.host, '\n');

  const inputs = [
    `${STAKE_RECORD_ID}field`,
    STAKE_AMOUNT,
    ADDR_PROVIDER,
  ];

  console.log('📤 Diffusion de « stake » avec :');
  console.log('  programName:', STAKE_PROGRAM_ID);
  console.log('  inputs     :', inputs);
  console.log('  fee        :', FEE);

  try {
    const txId = await programManager.execute({
      programName:  STAKE_PROGRAM_ID,
      functionName: 'stake',
      inputs,
      privateKey:   account.privateKey(),
      privateFee:   false,
    });
    console.log('✅ Transaction envoyée ! ID:', txId);
    console.log('⏳ En attente de confirmation…');

    let confirmation, attempt = 0;
    do {
      attempt += 1;
      console.log(`Polling #${attempt}…`);
      try {
        confirmation = await getTransactionConfirmationStatus(txId);
      } catch (err) {
        console.warn(`   ⚠️ Erreur fetching confirmation status (tentative ${attempt}):`, err.message);
        confirmation = null;
      }

      if (!confirmation || confirmation.status !== 'accepted') {
        console.log('   …en attente 10 s avant le prochain essai');
        await new Promise(r => setTimeout(r, 10_000));
      }
    } while (!confirmation || confirmation.status !== 'accepted');

    console.log(`🎉 Transaction ${txId} status: ${confirmation.status}`);
  } catch (err) {
    console.error('❌ Erreur durant execute():', err.message);
    console.error(err.stack);
    if (err.response) {
      console.error('- response.status:', err.response.status);
      console.error('- response.data  :', err.response.data);
    }
  }
})();
