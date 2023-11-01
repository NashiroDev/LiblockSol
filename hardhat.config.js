/**
* @type import('hardhat/config').HardhatUserConfig
*/

require('dotenv').config();
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 999,
          },
        },
      }
    ],
  },

  networks: {

    hardhat: {
      chainId: 1337
    },
    // mainnet: {
    //   url: process.env.MAINNET_RPC_URL,
    //   accounts: [process.env.PRIVATE_KEY],
    //   saveDeployments: true,
    // },
    // mumbai: {
    //   url: process.env.MUMBAI_RPC_URL,
    //   accounts: [process.env.PRIVATE_KEY],
    //   saveDeployments: true,
    // },
    goerli: {
      url: process.env.GOERLI_RPC_URL,
      accounts: [process.env.PRIVATE_KEY],
      saveDeployments: true,
    },
    scroll: {
      chainId: 534352,
      url: process.env.SCROLL_RPC_URL,
      accounts: [process.env.PRIVATE_KEY],
      saveDeployments: true,
    },
    scrollSepolia: {
      chainId: 534351,
      url: process.env.SCROLL_SEPOLIA_RPC_URL,
      accounts: [process.env.PRIVATE_KEY],
      saveDeployments: true,
    },
  },
  etherscan: {
    apiKey: {
      scrollSepolia: 'dummy',
      scroll: 'dummy',
      goerli: process.env.ETHERSCAN_API_KEY,
    },
    customChains: [
      {
        network: "scrollSepolia",
        chainId: 534351,
        urls: {
          apiURL: 'https://sepolia-blockscout.scroll.io/api',
          browserURL: 'https://sepolia-blockscout.scroll.io/',
        },
      },
      {
        network: "scroll",
        chainId: 534352,
        urls: {
          apiURL: "https://blockscout.scroll.io/api",
          browserURL: 'https://blockscout.scroll.io/',
        },
      }
    ]
  }
};