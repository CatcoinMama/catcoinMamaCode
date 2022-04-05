const testHelpers = require('./helpers/test_helpers');
const {fees} = require("../config/token_config");
const {
    assertBigNumberEqual, tokenToRaw, percentToRaw, getEthBalance, toWei, assertBigNumberGt, assertFailure
} = require("./helpers/test_utils");
const {getNamedAccounts} = require("hardhat");
let namedAccounts;
let token;

contract('CATSMAMA FEES TEST', (accounts) => {
    before(async () => {
        namedAccounts = await getNamedAccounts();
        token = await testHelpers.reinitializeToken(accounts);
        await testHelpers.setupLiquidity(token, accounts);
    })

    // CREATION
    it('should create an initial balance of 10000 for the account[1]', async () => {
        const balance = await token.balanceOf(accounts[1])
        assertBigNumberEqual(balance, tokenToRaw(10000))
    })

    // TRANSFER
    it('transfers: should transfer without fees 10000 to accounts[2] with accounts[1] having 10000', async () => {
        await token.transfer(accounts[2], tokenToRaw(10000), {from: accounts[1]});
        const balance = await token.balanceOf(accounts[2]);
        assertBigNumberEqual(balance, tokenToRaw(10000))
    })

    it('transfers: should transfer without fees 10000 to accounts[1] with accounts[0] having 10000', async () => {
        token = await testHelpers.reinitializeToken(accounts);
        await testHelpers.setupLiquidity(token, accounts);
        await token.transfer(accounts[2], tokenToRaw(10000), {from: accounts[0]});
        const balance = await token.balanceOf(accounts[2]);
        assertBigNumberEqual(balance, tokenToRaw(10000))
    })

    it('transfers: balances match after transfer with fees', async () => {
        token = await testHelpers.reinitializeToken(accounts);
        await testHelpers.setupLiquidity(token, accounts);
        await token.transfer(accounts[2], tokenToRaw(10000), {from: accounts[1]});
        const balance = await token.balanceOf(accounts[2]);
        assertBigNumberEqual(balance, tokenToRaw(10000))
    })

    // total supply & burnt
    it('total supply: total supply should not be reduced because no burns', async () => {
        const totalSupply = await token.totalSupply();
        assertBigNumberEqual(totalSupply, tokenToRaw(1_000_000_000_000_000));
    });

    // Isolated fees
    it('isolated fees: marketing taxes should be correctly initialized', async () => {
        const marketingTax = await token.taxMarketing();
        assertBigNumberEqual(marketingTax, percentToRaw(fees.marketingFee));
    });

    // wallet balances
    it('isolated fees: marketing wallet has BNB', async () => {
        const marketingWallet = await getEthBalance(namedAccounts.marketingWallet);
        assertBigNumberEqual(marketingWallet, '10000000000000000000000');
    });

    // Do some swaps
    it('Perform default buy sell', async () => {
        await testHelpers.performDefaultBuySell(token, accounts[1]);
    })

    // wallet balances
    it('isolated fees: marketing wallet has BNB', async () => {
        const marketingWallet = await getEthBalance(namedAccounts.marketingWallet);
        assertBigNumberGt(marketingWallet, toWei(0));
    });

    // exclusions
    it('Excluding account[2] from dividends and fees work', async () => {
        await token.excludeAccountFromFeesAndDividends(accounts[2], true)
        assert.ok(await token.isExcludedFromFee(accounts[2]));
        assert.ok(await token.isExcludedFromDividends(accounts[2]));
    });

    // wallet balances
    it('Settings fees above limit should fail', async () => {
        await assertFailure(() => token.setTaxLiquidity(700));
        await assertFailure(() => token.setTaxBurn(700));
        await assertFailure(() => token.setTaxDevelopment(900));
        await assertFailure(() => token.setTaxDonation(900));
        await assertFailure(() => token.setTaxMarketing(900));
        await assertFailure(() => token.setTaxDividend(900));
    });
})