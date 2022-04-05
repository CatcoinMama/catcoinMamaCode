const testHelpers = require('./helpers/test_helpers');
const {
    assertBigNumberGt,
    assertBigNumberLt, rawToTokenNumber, getEthBalance, fromWei, tokenToRaw
} = require("./helpers/test_utils");
let token;

contract('CATSMAMA OWNER TEST', (accounts) => {
    before(async () => {
        token = await testHelpers.reinitializeToken(accounts, 0);
        await testHelpers.setupLiquidity(token, accounts);
    });

    it('Token owner is account[0]', async () => {
        const owner = await token.owner();
        assert.strictEqual(owner, accounts[0]);
    });

    it('account[0] is excluded from fees', async () => {
        const isExcluded = await token.isExcludedFromFee(accounts[0]);
        assert(isExcluded);
    });

    it('Buying tokens for 0.3 ETH should work with fees', async () => {
        await testHelpers.buyTokens(token, 0.3, accounts[1]);
        const balance = await token.balanceOf(accounts[1])
        assertBigNumberGt(balance, tokenToRaw(2_500_000_000));
        assertBigNumberLt(balance, tokenToRaw(3_000_000_000));
    });

    it('Token ownership is transfered to account[2]', async () => {
        token = await testHelpers.reinitializeToken(accounts, 0);
        await testHelpers.setupLiquidity(token, accounts);
        await token.transferOwnership(accounts[2], {from: accounts[0]});
        const owner = await token.owner();
        assert.strictEqual(owner, accounts[2]);
    });

    it('account[2] is excluded from fees', async () => {
        const isExcluded = await token.isExcludedFromFee(accounts[2]);
        assert(isExcluded);
    });

    it('Buying tokens for 0.3 ETH should work, but with no fees', async () => {
        await testHelpers.buyTokens(token, 0.3, accounts[2]);
        const balance = await token.balanceOf(accounts[2])
        const balanceInTokens = rawToTokenNumber(balance);
        assertBigNumberGt(balance, tokenToRaw(2_500_000_000));
        assertBigNumberLt(balance, tokenToRaw(3_500_000_000));
    });
})