module.exports = {
    apps: [
      // Instance 1
      {
        name: 'submit-price-1',
        script: './src/submit.ts',
        env: {
          PK_PROVIDER: process.env.PK1,
          ADDR_PROVIDER: process.env.ADDR1,
          EXPLORER_ENDPOINT: process.env.EXPLORER_ENDPOINT,
          RPC_ENDPOINT: process.env.RPC_ENDPOINT,
          STAKE_RECORD_ID: process.env.STAKE_RECORD_ID,
          INTERVAL: process.env.INTERVAL,
          MARGIN: process.env.MARGIN,
          FEE: process.env.FEE,
          CMC_API_KEY: process.env.CMC_API_KEY,
        },
        interpreter: 'node',
      },
      // Instance 2
      {
        name: 'submit-price-2',
        script: './src/submit.ts',
        env: {
          PK_PROVIDER: process.env.PK2,
          ADDR_PROVIDER: process.env.ADDR2,
          EXPLORER_ENDPOINT: process.env.EXPLORER_ENDPOINT,
          RPC_ENDPOINT: process.env.RPC_ENDPOINT,
          STAKE_RECORD_ID: process.env.STAKE_RECORD_ID,
          INTERVAL: process.env.INTERVAL,
          MARGIN: process.env.MARGIN,
          FEE: process.env.FEE,
          CMC_API_KEY: process.env.CMC_API_KEY,
        },
        interpreter: 'node',
      },
      // Instance 3
      {
        name: 'submit-price-3',
        script: './src/submit.ts',
        env: {
          PK_PROVIDER: process.env.PK3,
          ADDR_PROVIDER: process.env.ADDR3,
          EXPLORER_ENDPOINT: process.env.EXPLORER_ENDPOINT,
          RPC_ENDPOINT: process.env.RPC_ENDPOINT,
          STAKE_RECORD_ID: process.env.STAKE_RECORD_ID,
          INTERVAL: process.env.INTERVAL,
          MARGIN: process.env.MARGIN,
          FEE: process.env.FEE,
          CMC_API_KEY: process.env.CMC_API_KEY,
        },
        interpreter: 'node',
      },
      // Instance 4
      {
        name: 'submit-price-4',
        script: './src/submit.ts',
        env: {
          PK_PROVIDER: process.env.PK4,
          ADDR_PROVIDER: process.env.ADDR4,
          EXPLORER_ENDPOINT: process.env.EXPLORER_ENDPOINT,
          RPC_ENDPOINT: process.env.RPC_ENDPOINT,
          STAKE_RECORD_ID: process.env.STAKE_RECORD_ID,
          INTERVAL: process.env.INTERVAL,
          MARGIN: process.env.MARGIN,
          FEE: process.env.FEE,
          CMC_API_KEY: process.env.CMC_API_KEY,
        },
        interpreter: 'node',
      },
      // Instance 5
      {
        name: 'submit-price-5',
        script: './src/submit.ts',
        env: {
          PK_PROVIDER: process.env.PK5,
          ADDR_PROVIDER: process.env.ADDR5,
          EXPLORER_ENDPOINT: process.env.EXPLORER_ENDPOINT,
          RPC_ENDPOINT: process.env.RPC_ENDPOINT,
          STAKE_RECORD_ID: process.env.STAKE_RECORD_ID,
          INTERVAL: process.env.INTERVAL,
          MARGIN: process.env.MARGIN,
          FEE: process.env.FEE,
          CMC_API_KEY: process.env.CMC_API_KEY,
        },
        interpreter: 'node',
      },
      // Instance 6
      {
        name: 'submit-price-6',
        script: './src/submit.ts',
        env: {
          PK_PROVIDER: process.env.PK6,
          ADDR_PROVIDER: process.env.ADDR6,
          EXPLORER_ENDPOINT: process.env.EXPLORER_ENDPOINT,
          RPC_ENDPOINT: process.env.RPC_ENDPOINT,
          STAKE_RECORD_ID: process.env.STAKE_RECORD_ID,
          INTERVAL: process.env.INTERVAL,
          MARGIN: process.env.MARGIN,
          FEE: process.env.FEE,
          CMC_API_KEY: process.env.CMC_API_KEY,
        },
        interpreter: 'node',
      },
      // Instance 7
      {
        name: 'submit-price-7',
        script: './src/submit.ts',
        env: {
          PK_PROVIDER: process.env.PK7,
          ADDR_PROVIDER: process.env.ADDR7,
          EXPLORER_ENDPOINT: process.env.EXPLORER_ENDPOINT,
          RPC_ENDPOINT: process.env.RPC_ENDPOINT,
          STAKE_RECORD_ID: process.env.STAKE_RECORD_ID,
          INTERVAL: process.env.INTERVAL,
          MARGIN: process.env.MARGIN,
          FEE: process.env.FEE,
          CMC_API_KEY: process.env.CMC_API_KEY,
        },
        interpreter: 'node',
      },
      // Instance 8
      {
        name: 'submit-price-8',
        script: './src/submit.ts',
        env: {
          PK_PROVIDER: process.env.PK8,
          ADDR_PROVIDER: process.env.ADDR8,
          EXPLORER_ENDPOINT: process.env.EXPLORER_ENDPOINT,
          RPC_ENDPOINT: process.env.RPC_ENDPOINT,
          STAKE_RECORD_ID: process.env.STAKE_RECORD_ID,
          INTERVAL: process.env.INTERVAL,
          MARGIN: process.env.MARGIN,
          FEE: process.env.FEE,
          CMC_API_KEY: process.env.CMC_API_KEY,
        },
        interpreter: 'node',
      },
    ],
  };
  