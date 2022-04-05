const {networkConfigs} = require("../config/network_config");

// Contract literals
const CATSMAMA = 'CATSMAMA'
const IterableMapping = 'IterableMapping'

// deployment
module.exports = async ({getNamedAccounts, network, deployments}) => {
    const isHardhat = network.name === 'hardhat';
    const gasConfig = networkConfigs[network.name].gasConfig;
    const catsAddress = networkConfigs[network.name].catsAddress;
    const privateSaleWallets = networkConfigs[network.name].privateSaleWallets;
    const {deploy, execute, get} = deployments;
    const {
        deployer,
        marketingWallet,
        developmentWallet,
        donationWallet,
    } = await getNamedAccountsOfNetwork(getNamedAccounts, network);

    // deploy IterableMapping
    const iterableMapping = await deploy(IterableMapping, {
        from: deployer, ...gasConfig,
        skipIfAlreadyDeployed: true,
    });

    // deploy CATSMAMA contract
    const constructorArguments = [
        catsAddress,
        marketingWallet,
        donationWallet,
        developmentWallet,
        networkConfigs[network.name].uniswapAddress,
        privateSaleWallets,
    ];
    const cats = await deploy(CATSMAMA, {
        from: deployer, ...gasConfig,
        skipIfAlreadyDeployed: false,
        libraries: {IterableMapping: iterableMapping.address},
        args: constructorArguments,
    });

    if (!isHardhat) {
        console.log(`Deployment completed at: ${new Date().toLocaleString()}`);
        console.log(`IterableMapping was deployed at:\n${iterableMapping.address}`);
        console.log(`CATSMAMA token was deployed at:\n${cats.address}`);
    }
};

// returns wallets required depends on the network
async function getNamedAccountsOfNetwork(getNamedAccounts, network) {
    if (network.name === 'hardhat') return getNamedAccounts();
    if (network.name === 'testnet' || network.name === 'production') return {
        deployer: process.env.DEPLOYER_WALLET,
        marketingWallet: process.env.MARKETING_WALLET,
        donationWallet: process.env.DONATION_WALLET,
        developmentWallet: process.env.DEVELOPMENT_WALLET,
    }
}

module.exports.tags = [CATSMAMA];