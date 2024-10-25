// require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();
// require("@nomiclabs/hardhat-ethers");
require("@nomicfoundation/hardhat-verify");
require('@openzeppelin/hardhat-upgrades');

const { RPC_URL, PRIVATE_KEY, ETHERSCAN_API_KEY } = process.env;


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  defaultNetwork: "mainnet",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
  networks: {
    hardhat: {},
    mainnet: {
      url: RPC_URL,
      accounts: [`0x${PRIVATE_KEY}`]
    },
    holesky: {
      url: RPC_URL,
      accounts: [`0x${PRIVATE_KEY}`]
   },
    testnet: {
      url: RPC_URL,
      accounts: [`0x${PRIVATE_KEY}`],
      // gas: 2100000,
      // gasPrice: 8000000000
    },
    matic: {
      allowUnlimitedContractSize: true,
      url: "https://matic-mumbai.chainstacklabs.com/",
      accounts: [`0x${PRIVATE_KEY}`],
      gas: 2100000,
      gasPrice: 8000000000
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  },


  sourcify: {
    // Disabled by default
    // Doesn't need an API key
    enabled: true
  }
};
