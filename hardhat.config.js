/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require('hardhat-contract-sizer');
require('@nomiclabs/hardhat-waffle');
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-etherscan");
require('hardhat-deploy');
require('dotenv').config();
const {forking} = require("./config/network_config");

module.exports = {
    defaultNetwork: 'hardhat',
    namedAccounts: {
        deployer: 0,
        tokenOwner: 0,
        stakingWallet: 6,
        liquidityWallet: 7,
        marketingWallet: 8,
        donationWallet: 8,
        developmentWallet: 8,
    },
    networks: {
        hardhat: {
            chainId: 56,
            loggingEnabled: false,
            forking,
            allowUnlimitedContractSize: false,
        },
        testnet: {
            url: `https://data-seed-prebsc-1-s1.binance.org:8545`,
            network_id: 97,
            loggingEnabled: true,
            accounts: {
                mnemonic: process.env.MNEMONIC,
            },
        },
        production: {
            url: `https://bsc-dataseed.binance.org/`,
            network_id: 56,
            loggingEnabled: true,
            accounts: {
                mnemonic: process.env.MNEMONIC,
            },
        },
    },
    etherscan: {
        apiKey: {
            // binance smart chain
            bsc: process.env.BSC_API_KEY,
            bscTestnet: process.env.BSC_API_KEY,
        }
    },
    solidity: {
        version: "0.8.2",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    },
    mocha: {
        timeout: 200000
    },
    contractSizer: {
        alphaSort: true,
        runOnCompile: false,
        strict: true,
    }
};