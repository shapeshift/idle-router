require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("hardhat-deploy");
require("solidity-coverage");
require("dotenv").config();

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.11",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      deploy: ["deploy/local", "deploy/core", "deploy/tic", "deploy/pools"],
    },
    goerli: {
      deploy: ["deploy"],
      url: process.env.GOERLI_URL,
      accounts:
        process.env.GOERLI_PRIVATE_KEY !== undefined
          ? [process.env.GOERLI_PRIVATE_KEY]
          : [],
    }
  },
  paths: {
    deploy: ["deploy/core"],
    sources: "./src",
  },
  namedAccounts: {
    admin: {
      default: 0,
    }
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
  },
  gasReporter: {
    enabled: false,
    currency: "USD",
  },
};
