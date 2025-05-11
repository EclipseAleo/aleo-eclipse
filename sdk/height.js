import https from 'https';
import { URL } from 'url';
import 'dotenv/config';

async function getCurrentBlockHeight() {
  const url = new URL('https://api.explorer.provable.com/v1/testnet/latest/height').toString();
  console.log(url)
  return new Promise((resolve, reject) => {
    https
      .get(url, res => {
        let data = '';
        res.on('data', chunk => (data += chunk));
        res.on('end', () => {
          if (res.statusCode === 200) {
            try {
              const height = JSON.parse(data);
              console.log('🔍 Hauteur actuelle du bloc :', height);
              resolve(height);
            } catch (err) {
              reject(new Error('Invalid JSON in response: ' + err.message));
            }
          } else {
            reject(new Error());
          }
        });
      })
      .on('error', reject);
  });
}

(async () => {
  try {
    const height = await getCurrentBlockHeight();
  } catch (err) {
    console.error('❌ Impossible de récupérer la hauteur de bloc :', err.message);
  }
})();
