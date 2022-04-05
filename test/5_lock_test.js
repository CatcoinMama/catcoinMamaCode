const testHelpers = require('./helpers/test_helpers');
const {assertFailure, tokenToRaw} = require("./helpers/test_utils");
const {setupLiquidityFromAccount} = require("./helpers/test_helpers");
let token;

contract('CATSMAMA LOCK TEST', (accounts) => {
    before(async () => {
        token = await testHelpers.reinitializeToken(accounts, 100_000_000, false);
        await token.transfer(accounts[3], tokenToRaw(500_000_000_000), {from: accounts[0]});
        await testHelpers.setupLiquidity(token, accounts);
    });

    it('Buying tokens for 0.3 ETH should work', async () => {
        await testHelpers.buyTokens(token, 0.3, accounts[0]);
        const balance = await token.balanceOf(accounts[0])
        assert.ok(balance);
    });

    it('Selling 80,000,000 tokens for ETH should work', async () => {
        await testHelpers.sellTokens(token, 80_000_000, accounts[0]);
        const balance = await token.balanceOf(accounts[0])
        assert.ok(balance);
    });

    it('Buying tokens for 0.3 ETH should fail from a regular account', async () => {
        await assertFailure(() => testHelpers.buyTokens(token, 0.3, accounts[1]));
    });

    it('Selling 80,000,000 tokens for ETH should fail from a regular account', async () => {
        await assertFailure(() => testHelpers.sellTokens(token, 80_000_000, accounts[1]));
    });

    it('Transferring tokens should fail from a regular account', async () => {
        await assertFailure(() => token.transfer(accounts[2], tokenToRaw(10_000), {from: accounts[1]}));
    });

    it('Buying/selling should work from excluded account', async () => {
        await token.setCanTradeInPresale(accounts[2], true);
        await testHelpers.buyTokens(token, 0.3, accounts[2]);
        await testHelpers.sellTokens(token, 80_000_000, accounts[2]);
    });

    it('Transferring tokens should work from excluded account', async () => {
        await token.transfer(accounts[3], tokenToRaw(10_000), {from: accounts[2]});
    });

    it('Token ownership is transfered to account[1]', async () => {
        await token.transferOwnership(accounts[1], {from: accounts[0]});
        const owner = await token.owner();
        assert.strictEqual(owner, accounts[1]);
    });

    it('Buying tokens for 0.3 ETH should work', async () => {
        await testHelpers.buyTokens(token, 0.3, accounts[1]);
        const balance = await token.balanceOf(accounts[1])
        assert.ok(balance);
    });

    it('Selling 80,000,000 tokens for ETH should work', async () => {
        await testHelpers.sellTokens(token, 80_000_000, accounts[1]);
        const balance = await token.balanceOf(accounts[1])
        assert.ok(balance);
    });

    /// Liquidity restrictions

    it('Adding liquidity from regular account should fail', async () => {
        await assertFailure(() => setupLiquidityFromAccount(token, accounts[3], 10, 100_000_000_000));
    });
})