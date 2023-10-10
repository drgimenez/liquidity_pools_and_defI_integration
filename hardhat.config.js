require('dotenv').config();
require('@nomiclabs/hardhat-ethers');
require('solidity-coverage');
require('hardhat-contract-sizer');

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.21",
  paths: {
    sources: "./src",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  networks: {
    hardhat: {
        forking: {
            url: process.env.POLYGON_ACCESSPOINT_URL,
            blockNumber: 48487827
        }
    },
    mumbai: {
        chainId: 80001,
        timeout: 20000,
        gasPrice: 8000000000,
        url: process.env.POLYGON_MUMBAI_ACCESSPOINT_URL,
        from: process.env.POLYGON_ACCOUNT,
        accounts: [process.env.POLYGON_PRIVATE_KEY]
    }
  }
};
