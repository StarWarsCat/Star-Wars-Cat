require("@nomiclabs/hardhat-waffle");

// hardhat upgrade plugins
require('@nomiclabs/hardhat-ethers');
require('@openzeppelin/hardhat-upgrades');

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      accounts: {
        mnemonic: ''
      },
      gas: 'auto',
    },
    okt: {
      url: 'https://exchaintestrpc.okex.org',
      accounts: {
        mnemonic: ''
      },
      gas: 'auto',
    },
    oec: {
      url: 'https://exchainrpc.okex.org',
      accounts: [],
      gas: 'auto',
    },
    bsc_test: {
      url: 'https://data-seed-prebsc-1-s3.binance.org:8545',
      accounts: [],
      gas: 'auto',
      gasPrice: 'auto'
    },
  },
};
