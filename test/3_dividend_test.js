const testHelpers = require('./helpers/test_helpers');
const {
    assertBigNumberEqual,
    tokenToRaw,
    rawToTokenNumber,
    assertBigNumberGt, assertBigNumberLt, rawToToken, assertBigNumberEqualApprox, assertFailure, bigNumber,
} = require("./helpers/test_utils");
const {web3, network} = require("hardhat");
const {erc20Abi} = require("./definitions/erc20Abi");
const {networkConfigs} = require("../config/network_config");
let token;
let cats;

contract('CATSMAMA DIVIDEND TEST', (accounts) => {
    before(async () => {
        token = await testHelpers.reinitializeToken(accounts, 100_000_000);
        await token.transfer(accounts[2], tokenToRaw(500_000), {from: accounts[0]})
        await token.transfer(accounts[4], tokenToRaw(1_000_000), {from: accounts[0]})
        const catsAddress = networkConfigs[network.name].catsAddress;
        cats = new web3.eth.Contract(erc20Abi, catsAddress);
    });

    // Dividend tracker tests
    it('account[0] should be ignored from dividends, and account[1] should not be', async () => {
        const account0Excluded = await token.isExcludedFromDividends(accounts[0])
        const account1Excluded = await token.isExcludedFromDividends(accounts[1])
        assert.equal(account0Excluded, true);
        assert.equal(account1Excluded, false);
    });
    it('should create an initial balance of 100000000 for the account[1]', async () => {
        const balance = await token.balanceOf(accounts[1])
        assertBigNumberEqual(balance, tokenToRaw(100_000_000))
    });

    it('should have 0 withdrawable dividend for the account[1]', async () => {
        const dividends = await token.withdrawableDividendsOf(accounts[1])
        assertBigNumberEqual(dividends, tokenToRaw(0))
    });

    // Do swaps to create dividends while auto transfer off
    it('Perform default buy sell', async () => {
        token = await testHelpers.reinitializeToken(accounts, 100_000_000);
        await token.transfer(accounts[2], tokenToRaw(500_000), {from: accounts[0]})
        await token.transfer(accounts[4], tokenToRaw(1_000_000), {from: accounts[0]})
        await token.switchAutoDividendProcessing(false);
        await testHelpers.setupLiquidity(token, accounts);
        await testHelpers.performDefaultBuySell(token, accounts[2]);
    })

    it('account[1] should have dividends after buy sell transactions', async () => {
        const totalDividends = bigNumber(await token.withdrawableDividendsOf(accounts[1]))
            .add(bigNumber(await token.withdrawableDividendsOf(accounts[2])));
        assertBigNumberEqualApprox(totalDividends, 10415535995);
    });

    it('account[3] should fail to claim any dividends, it doesnt have any', async () => {
        await assertFailure(() => token.claimDividends({from: accounts[3]}));
    });

    it('account[2] should correctly claim dividends', async () => {
        const balanceA = bigNumber(await cats.methods.balanceOf(accounts[2]).call());
        const withdrawable = bigNumber(await token.withdrawableDividendsOf(accounts[2]));
        await token.claimDividends({from: accounts[2]});
        const balanceB = bigNumber(await cats.methods.balanceOf(accounts[2]).call())
        const withdrawnAmount = bigNumber(await token.withdrawnDividendsOf(accounts[2]))
        assertBigNumberEqualApprox(balanceA.add(withdrawable), balanceB, 0.04);
        assertBigNumberEqualApprox(withdrawable, withdrawnAmount, 0.04);
    });

    it('accounts[4] should have dividends after buy sell transactions', async () => {
        const withdrawable = bigNumber(await token.withdrawableDividendsOf(accounts[4]));
        assertBigNumberEqualApprox(withdrawable, 21244, 0.04);
        const balanceA = bigNumber(await cats.methods.balanceOf(accounts[4]).call());
        await token.claimDividends({from: accounts[4]});
        const balanceB = bigNumber(await cats.methods.balanceOf(accounts[4]).call());
        assertBigNumberGt(balanceB, balanceA);
    });

    // Do swaps to create dividends
    it('Perform default buy sell', async () => {
        token = await testHelpers.reinitializeToken(accounts, 100_000_000);
        await token.transfer(accounts[2], tokenToRaw(500_000), {from: accounts[0]})
        await testHelpers.setupLiquidity(token, accounts);
        await testHelpers.performDefaultBuySell(token, accounts[2]);
    })

    it('account[1] should have dividends after buy sell transactions', async () => {
        const totalDividends = bigNumber(await token.cumulativeDividendsOf(accounts[1]))
            .add(bigNumber(await token.cumulativeDividendsOf(accounts[2])));
        assertBigNumberEqualApprox(totalDividends, 10415535995);
    });

    it('account[2] should have correctly claim dividends automatically', async () => {
        const withdrawable = bigNumber(await token.withdrawableDividendsOf(accounts[2]));
        await assertFailure(() => token.claimDividends({from: accounts[2]}));
        assertBigNumberEqualApprox(withdrawable, 0, 0.04);
    });
})