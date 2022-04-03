require("@nomiclabs/hardhat-waffle");
require("hardhat-deploy");
require("solidity-coverage");
require("dotenv").config();
require("@openzeppelin/hardhat-upgrades");

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
      deploy: ["deploy/core"],
      chainId: 1,
      forking: {
        url: process.env.MAINNET_URL || "",
        blockNumber: Number(process.env.FORK_BLOCK_NUMBER),
        enabled: true, // Set to false to disable forked mainnet mode
      },
    },
  },
  paths: {
    deploy: ["deploy/core"],
    sources: "./src",
  },
  namedAccounts: {
    admin: {
      default: 0,
    },
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
