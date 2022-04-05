const decimals = 18;
const dividendWallet = '0x0000000000000000000000000000000000000dab';
const fees = {
    dividendFee: 2,
    burnFee: 1,
    marketingFee: 1,
    donationFee: 1,
    developmentFee: 1,
    liquidityFee: 1,
}
const slippageTolerance = {
    minBuySlippage: 7, maxBuySlippage: 8, minSellSlippage: 7, maxSellSlippage: 10,
}

module.exports = {
    fees, slippageTolerance, decimals, dividendWallet,
}