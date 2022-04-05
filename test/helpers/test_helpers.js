const testUtils = require("./test_utils");
const {tokenToRaw, rawToToken, getETHToTokenPath, rawToTokenNumber} = require("./test_utils");
const IUniswapV2Router02 = artifacts.require('IUniswapV2Router02')
const IUniswapV2Pair = artifacts.require('IUniswapV2Pair')
const CATSMAMA = artifacts.require('CATSMAMA');
const {deployments, network, getNamedAccounts, web3} = require('hardhat');
const {forking, deadWallet} = require("../../config/network_config");

async function resetNetwork() {
    if (network.name !== 'hardhat') return;
    await network.provider.request({
        method: "hardhat_reset", params: [{forking: {jsonRpcUrl: forking.url, blockNumber: forking.blockNumber}},],
    });
}

async function initializeWithDeployedToken(accounts, account1Balance = 10000) {
    const tokenDep = await deployments.get('CATSMAMA');
    const token = await CATSMAMA.at(tokenDep.address);
    await token.transfer(accounts[1], tokenToRaw(account1Balance), {from: accounts[0]})
    return token;
}

async function reinitializeToken(accounts, account1Balance = 10000, completePresale = true) {
    await resetNetwork();
    await deployments.fixture(['CATSMAMA']);
    const tokenDep = await deployments.get('CATSMAMA');
    const token = await CATSMAMA.at(tokenDep.address);
    await token.transfer(accounts[1], tokenToRaw(account1Balance), {from: accounts[0]})
    if (completePresale) await token.completePresale();
    return token;
}

async function setupLiquidity(token, accounts, liquidityETHAmount = 1000, liquidityTokenAmount = 10_000_000_000_000) {
    const routerAddress = await token.uniswapV2Router();
    const totalSupply = await token.totalSupply();
    await token.approve(routerAddress, totalSupply, {from: accounts[0]});
    const router = await IUniswapV2Router02.at(routerAddress);
    await router.addLiquidityETH(token.address, tokenToRaw(liquidityTokenAmount), 0, 0, deadWallet, new Date().getTime() + 3600000, {
        from: accounts[0],
        value: testUtils.toWei(liquidityETHAmount)
    });
}

async function setupLiquidityFromAccount(token, account, liquidityETHAmount = 1000, liquidityTokenAmount = 10_000_000_000_000) {
    const routerAddress = await token.uniswapV2Router();
    const totalSupply = await token.totalSupply();
    await token.approve(routerAddress, totalSupply, {from: account});
    const router = await IUniswapV2Router02.at(routerAddress);
    await router.addLiquidityETH(token.address, tokenToRaw(liquidityTokenAmount), 0, 0, deadWallet, new Date().getTime() + 3600000, {
        from: account,
        value: testUtils.toWei(liquidityETHAmount)
    });
}

async function buyTokens(token, ethAmount, account) {
    const routerAddress = await token.uniswapV2Router();
    const router = await IUniswapV2Router02.at(routerAddress);
    await router.swapExactETHForTokensSupportingFeeOnTransferTokens(0, await testUtils.getETHToTokenPath(token, router), account, new Date().getTime() + 3600000, {
        from: account,
        value: testUtils.toWei(ethAmount)
    });
}

async function sellTokens(token, tokenAmount, account) {
    const routerAddress = await token.uniswapV2Router();
    const router = await IUniswapV2Router02.at(routerAddress);
    await token.approve(routerAddress, tokenToRaw(tokenAmount), {from: account});
    await router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenToRaw(tokenAmount), 0, await testUtils.getTokenToETHPath(token, router), account, new Date().getTime() + 3600000, {from: account});
}

async function performDefaultBuySell(token, account) {
    // Do swaps to create dividends
    await buyTokens(token, 60, account);
    const balanceB = await token.balanceOf(account)
    const balanceInTokensB = rawToTokenNumber(balanceB);
    assert(balanceInTokensB > 500_000_000_000 && balanceInTokensB < 600_000_000_000, `${balanceInTokensB} is not in the correct range`);

    await sellTokens(token, 500_000_000_000, account);
    const balanceS = await token.balanceOf(account)
    const balanceInTokensS = rawToTokenNumber(balanceS);
    assert(balanceInTokensS > 20_000_000_000 && balanceInTokensS < 30_000_000_000, `${balanceInTokensS} is not in the correct range`);
}

function getTransferAmount(amount, config) {
    const taxAmount = amount * config.dividendFee / 100;
    const burnAmount = amount * config.burnFee / 100;
    const marketingAmount = amount * config.marketingFee / 100;
    const donationAmount = amount * config.donationFee / 100;
    const developmentAmount = amount * config.developmentFee / 100;
    const liquidityAmount = amount * config.liquidityFee / 100;
    return amount - (taxAmount + burnAmount + marketingAmount + donationAmount + developmentAmount + liquidityAmount);
}

async function getTokenPairOfUniswapFactory(token) {
    return IUniswapV2Pair.at(await token.uniswapV2Pair());
}

async function getTokenReserves(token) {
    const pair = await IUniswapV2Pair.at(await token.uniswapV2Pair());
    const reserves = await pair.getReserves();
    try {
        return [testUtils.fromWei(reserves.reserve0), rawToToken(reserves.reserve1)];
    } catch (ex) {
        return [testUtils.fromWei(reserves.reserve1), rawToToken(reserves.reserve0)];
    }
}

async function getPriceOfTokenInETH(token) {
    return 1 / (await getTokenAmountForETH(token, 1));
}

async function getTokenAmountForETH(token, ethMount) {
    const router = await IUniswapV2Router02.at(await token.uniswapV2Router());
    const tokenRawAmount = await router.getAmountsOut(ethMount, await getETHToTokenPath(token, router));
    return tokenRawAmount[1];
}

function getContractCallTxData(contract, methodName, params) {
    let method = contract.abi.find((method) => method.name === methodName);
    return web3.eth.abi.encodeFunctionCall(method, params);
}

async function timeTravelMinutes(delayMinutes) {
    await network.provider.send("evm_increaseTime", [delayMinutes * 60])
    await network.provider.send("evm_mine")
}

async function timeTravelHours(delayHours) {
    await network.provider.send("evm_increaseTime", [delayHours * 3600])
    await network.provider.send("evm_mine")
}

async function timeTravelDays(delayDays) {
    await network.provider.send("evm_increaseTime", [delayDays * 3600 * 24])
    await network.provider.send("evm_mine")
}

module.exports = {
    resetNetwork,
    getTransferAmount,
    getTokenPairOfUniswapFactory,
    getTokenReserves,
    getPriceOfTokenInETH,
    reinitializeToken,
    initializeWithDeployedToken,
    getTokenAmountForETH,
    setupLiquidity,
    setupLiquidityFromAccount,
    buyTokens,
    sellTokens,
    getContractCallTxData,
    timeTravelMinutes,
    timeTravelHours,
    timeTravelDays,
    performDefaultBuySell,
}