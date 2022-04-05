const testHelpers = require('./helpers/test_helpers');
const {assertFailure, tokenToRaw, rawToToken} = require("./helpers/test_utils");
const {timeTravelDays} = require("./helpers/test_helpers");
let token;

contract('CATSMAMA RESTRICTION TEST', (accounts) => {
    before(async () => {
        token = await testHelpers.reinitializeToken(accounts, 10_000, true);
        await testHelpers.setupLiquidity(token, accounts);
    });
    it('isolated fees: donation tax cannot be below 1%', async () => {
        await assertFailure(() => token.setTaxDonation(90));
    });
    it('isolated fees: total tax cannot be above 9%', async () => {
        await assertFailure(() => token.setTaxDonation(900));
    });
    it('Should not allow above maximum wallet size', async () => {
        await token.transfer(accounts[2], tokenToRaw(10_000_000_000_000));
        await assertFailure(() => token.transfer(accounts[2], tokenToRaw(10_000_000_000_000)));
    });
    it('Should allow above maximum wallet size after excluding', async () => {
        await token.excludeAccountFromWalletCap(accounts[2], true);
        await token.transfer(accounts[2], tokenToRaw(10_000_000_000_000));
    });

    // Vesting
    it('Should not allow above 25% in the first two weeks', async () => {
        token = await testHelpers.reinitializeToken(accounts, 10_000, false);
        await testHelpers.setupLiquidity(token, accounts);

        await token.transfer(accounts[4], tokenToRaw(1_000_000));
        await token.vestPrivateSaleWallets();
        await token.completePresale();
        await token.transfer(accounts[5], tokenToRaw(250_000), {from: accounts[4]});
        await assertFailure(() => token.transfer(accounts[5], tokenToRaw(250_000), {from: accounts[4]}));
    });

    it('Should not allow above 50% in the third week', async () => {
        await timeTravelDays(7);
        await assertFailure(() => token.transfer(accounts[5], tokenToRaw(250_000), {from: accounts[4]}));
        await timeTravelDays(7);
        await token.transfer(accounts[5], tokenToRaw(250_000), {from: accounts[4]});
    });


    it('Should not allow above 75% in the fourth week', async () => {
        await timeTravelDays(3);
        await assertFailure(() => token.transfer(accounts[5], tokenToRaw(250_000), {from: accounts[4]}));
        await timeTravelDays(4);
        await token.transfer(accounts[5], tokenToRaw(250_000), {from: accounts[4]});
    });

    it('Should allow 100% after the fourth week', async () => {
        await timeTravelDays(3);
        await assertFailure(() => token.transfer(accounts[5], tokenToRaw(250_000), {from: accounts[4]}));
        await timeTravelDays(4);
        await token.transfer(accounts[5], tokenToRaw(250_000), {from: accounts[4]});
    });

    // Buy Sell tests
    it('Should not allow above 25% selling in the first two weeks', async () => {
        token = await testHelpers.reinitializeToken(accounts, 10_000, false);
        await testHelpers.setupLiquidity(token, accounts);

        await token.transfer(accounts[5], tokenToRaw(1_000_000));
        await token.vestPrivateSaleWallets();
        await token.completePresale();
        await testHelpers.sellTokens(token, 250_000, accounts[5]);
        await assertFailure(() => testHelpers.sellTokens(token, 250_000, accounts[5]));
    });

    it('Calling vest again should fail', async () => {
        await assertFailure(() => token.vestPrivateSaleWallets());
    });
})