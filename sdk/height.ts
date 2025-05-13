import https from "https";
import { URL } from "url";
import "dotenv/config";

async function getCurrentBlockHeight(): Promise<number> {
  const url = new URL(
    process.env.EXPLORER_ENDPOINT + "/" + process.env.NETWORK + "/latest/height"
  ).toString();
  console.log(url);
  return new Promise<number>((resolve, reject) => {
    https
      .get(url, (res) => {
        let data = "";
        res.on("data", (chunk: Buffer | string) => (data += chunk));
        res.on("end", () => {
          if (res.statusCode === 200) {
            try {
              const height: number = JSON.parse(data);
              console.log("🔍 Hauteur actuelle du bloc :", height);
              resolve(height);
            } catch (err: any) {
              reject(new Error("Invalid JSON in response: " + err.message));
            }
          } else {
            reject(
              new Error(`Request failed with status code ${res.statusCode}`)
            );
          }
        });
      })
      .on("error", reject);
  });
}

(async () => {
  try {
    const height: number = await getCurrentBlockHeight();
    console.log('Block height fetched successfully:', height);
  } catch (err: any) {
    console.error(
      "❌ Impossible de récupérer la hauteur de bloc :",
      err.message
    );
  }
})();
