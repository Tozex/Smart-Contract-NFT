require('dotenv').config();
const HDWalletProvider = require('truffle-hdwallet-provider');
const web3 = require('web3');

const rinkebyUrl=`https://rinkeby.infura.io/v3/${process.env.RINKEBYINFURA}`;
module.exports = {
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */

  networks: {
    // Useful for testing. The `development` name is special - truffle uses it by default
    // if it's defined here and no other network is specified at the command line.
    // You should run a client (like ganache-cli, geth or parity) in a separate terminal
    // tab if you use this network and you must also set the `host`, `port` and `network_id`
    // options below to some value.
    //
    // development: {
    //  host: "127.0.0.1",     // Localhost (default: none)
    //  port: 8545,            // Standard Ethereum port (default: none)
    //  network_id: '*',       // Any network (default: none)
    //  gasPrice: 2000000000,
    //   gas: 0xfffffffffff,
    // },
    // Another network with more advanced options...
    // advanced: {
    // port: 8777,             // Custom port
    // network_id: 1342,       // Custom network
    // gas: 8500000,           // Gas sent with each transaction (default: ~6700000)
    // gasPrice: 20000000000,  // 20 gwei (in wei) (default: 100 gwei)
    // from: <address>,        // Account to send txs from (default: accounts[0])
    // websockets: true        // Enable EventEmitter interface for web3 (default: false)
    // },
    // Useful for deploying to a public network.
    // NB: It's important to wrap the provider as a function.
    // ropsten: {
    //   provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/3fadc625e3e34e17aeb49c73b8e46f0e`),
    //   network_id: 3,       // Ropsten's id
    //   gas: 5500000,        // Ropsten has a lower block limit than mainnet
    //   confirmations: 2,    // # of confs to wait between deployments. (default: 0)
    //   timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
    //   skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    // },
    rinkeby: {
      provider() {
        return new HDWalletProvider(process.env.PRIVATEKEY, rinkebyUrl, 0);
      },
      networkCheckTimeout:100000,
      network_id: 4,
      gasPrice: 2000000000,
      gas: 4712388,
    },
    testnet: {
      provider: () => new HDWalletProvider(process.env.PRIVATEKEY, `https://data-seed-prebsc-1-s1.binance.org:8545/`),
      network_id: 97,
      confirmations: 2,
      gasPrice: 20000000000,
      timeoutBlocks: 10000,
      skipDryRun: true,
      networkCheckTimeout:999999
    },
    mumbai: {
      provider: () => new HDWalletProvider(process.env.PRIVATEKEY, `wss://polygon-mumbai.g.alchemy.com/v2/LcBqud-AYtt-2uHZ8jNniZZFBJ2bPyZt`),
      network_id: 80001,
      confirmations: 2,
      timeoutBlocks: 200,
      networkCheckTimeout: 999999,
      skipDryRun: false
    },

    // Useful for private networks
    // private: {
    // provider: () => new HDWalletProvider(mnemonic, `https://network.io`),
    // network_id: 2111,   // This network is yours, in the cloud.
    // production: true    // Treats this network as if it was a public net. (default: false)
    // }
  },
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
    etherscan: process.env.ETHERSCAN_API_KEY,
    bscscan: process.env.BSCSCAN_API_KEY
  },
  // Set default mocha options here, use special reporters etc.
  mocha: {
     timeout: 300000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "^0.8.0",    // Fetch exact version from solc-bin (default: truffle's version)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200
       }
      }
    }
  }
};