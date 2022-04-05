const testUtils = require('./helpers/test_utils');
const testHelpers = require('./helpers/test_helpers');
const {assertBigNumberEqual, tokenToRaw, rawToToken} = require("./helpers/test_utils");
let token;

contract('CATSMAMA GENERAL TEST', (accounts) => {
    before(async () => {
        token = await testHelpers.reinitializeToken(accounts);
    });

    // META DATA
    it('creation: should create an initial balance of 10000 for the creator', async () => {
        const balance = await token.balanceOf(accounts[1])
        assertBigNumberEqual(balance, tokenToRaw(10000))
    })
    it('creation: test correct setting of meta information', async () => {
        const name = await token.name()
        assert.strictEqual(name, 'Catcoin Mama')

        const decimals = await token.decimals()
        assert.strictEqual(decimals.toNumber(), 18)

        const symbol = await token.symbol()
        assert.strictEqual(symbol, 'CATSMAMA')
    })

    // TRANSFERS
    it('transfers: should transfer 10000 to accounts[2] with accounts[1] having 10000', async () => {
        await token.transfer(accounts[2], tokenToRaw(10000), {from: accounts[1]})
        const balance = await token.balanceOf(accounts[2])
        assertBigNumberEqual(balance, tokenToRaw(10000))
    })

    it('transfers: should fail when trying to transfer 10001 to accounts[2] with accounts[1] having 10000', async () => {
        await testUtils.assertFailure(
            () => token.transfer(accounts[3], tokenToRaw(10001), {from: accounts[2]})
        );
    })

    it('transfers: should handle zero-transfers normally', async () => {
        const balanceBefore = await token.balanceOf(accounts[2])
        await token.transfer(accounts[2], tokenToRaw(0), {from: accounts[1]})
        const balance = await token.balanceOf(accounts[2])
        assertBigNumberEqual(balance, balanceBefore)
    })

    // APPROVALS
    it('approvals: msg.sender should approve 100 to accounts[1]', async () => {
        token = await testHelpers.reinitializeToken(accounts);
        await token.approve(accounts[2], tokenToRaw(100), {from: accounts[1]})
        const allowance = await token.allowance(accounts[1], accounts[2])
        assertBigNumberEqual(allowance, tokenToRaw(100))
    })

    it('approvals: msg.sender approves accounts[2] of 100 & withdraws 20 once.', async () => {
        const balance0 = await token.balanceOf(accounts[1])
        assertBigNumberEqual(balance0, tokenToRaw(10000))

        await token.approve(accounts[2], tokenToRaw(100), {from: accounts[1]}) // 100
        const balance2 = await token.balanceOf(accounts[2])
        assertBigNumberEqual(balance2, tokenToRaw(0), 'balance2 not token correct')

        await token.transferFrom(accounts[1], accounts[2], tokenToRaw(20), {from: accounts[2]}) // -20
        const allowance1 = await token.allowance(accounts[1], accounts[2])
        assertBigNumberEqual(allowance1, tokenToRaw(80)) // =tokenToRaw80

        const balance3 = await token.balanceOf(accounts[2])
        assertBigNumberEqual(balance3, tokenToRaw(20))

        const balance4 = await token.balanceOf(accounts[1])
        assertBigNumberEqual(balance4, tokenToRaw(9980))
    })

    // should approve 100 of msg.sender & withdraw 50, twice. (should succeed)
    it('approvals: msg.sender approves accounts[1] of 100 & withdraws 20 twice.', async () => {
        token = await testHelpers.reinitializeToken(accounts);
        await token.approve(accounts[2], tokenToRaw(100), {from: accounts[1]})
        const allowance01 = await token.allowance(accounts[1], accounts[2])
        assertBigNumberEqual(allowance01, tokenToRaw(100))

        await token.transferFrom(accounts[1], accounts[2], tokenToRaw(20), {from: accounts[2]})
        const allowance012 = await token.allowance(accounts[1], accounts[2])
        assertBigNumberEqual(allowance012, tokenToRaw(80))

        const balance2 = await token.balanceOf(accounts[2])
        assertBigNumberEqual(balance2, tokenToRaw(20))

        const balance0 = await token.balanceOf(accounts[1])
        assertBigNumberEqual(balance0, tokenToRaw(9980))

        // FIRST tx done.
        // onto next.
        await token.transferFrom(accounts[1], accounts[2], tokenToRaw(20), {from: accounts[2]})
        const allowance013 = await token.allowance(accounts[1], accounts[2])
        assertBigNumberEqual(allowance013, tokenToRaw(60))

        const balance22 = await token.balanceOf(accounts[2])
        assertBigNumberEqual(balance22, tokenToRaw(40))

        const balance02 = await token.balanceOf(accounts[1])
        assertBigNumberEqual(balance02, tokenToRaw(9960))
    })

    // should approve 100 of msg.sender & withdraw 50 & 60 (should fail).
    it('approvals: msg.sender approves accounts[1] of 100 & withdraws 50 & 60 (2nd tx should fail)', async () => {
        token = await testHelpers.reinitializeToken(accounts);
        await token.approve(accounts[2], tokenToRaw(100), {from: accounts[1]})
        const allowance01 = await token.allowance(accounts[1], accounts[2])
        assertBigNumberEqual(allowance01, tokenToRaw(100))

        await token.transferFrom(accounts[1], accounts[3], tokenToRaw(50), {from: accounts[2]})
        const allowance012 = await token.allowance(accounts[1], accounts[2])
        assertBigNumberEqual(allowance012, tokenToRaw(50))

        const balance2 = await token.balanceOf(accounts[3])
        assertBigNumberEqual(balance2, tokenToRaw(50))

        const balance0 = await token.balanceOf(accounts[1])
        assertBigNumberEqual(balance0, tokenToRaw(9950))

        // FIRST tx done.
        // onto next.
        await testUtils.assertFailure(
            () => token.transferFrom(accounts[1], accounts[3], tokenToRaw(60), {from: accounts[2]})
        );
    })

    it('approvals: attempt withdrawal from account with no allowance (should fail)', async () => {
        await testUtils.assertFailure(
            () => token.transferFrom(accounts[0], accounts[2], tokenToRaw(60), {from: accounts[1]})
        );
    })
    it('approvals: allow accounts[1] 100 to withdraw from accounts[0]. Withdraw 60 and then approve 0 & attempt transfer.', async () => {
        await token.approve(accounts[2], tokenToRaw(100), {from: accounts[1]})
        await token.transferFrom(accounts[1], accounts[2], tokenToRaw(60), {from: accounts[2]})
        await token.approve(accounts[2], tokenToRaw(0), {from: accounts[1]})
        await testUtils.assertFailure(
            () => token.transferFrom(accounts[1], accounts[2], tokenToRaw(60), {from: accounts[2]})
        );
    })
    it('approvals: approve max (2^256 - 1)', async () => {
        await token.approve(accounts[2], '115792089237316195423570985008687907853269984665640564039457584007913129639935', {from: accounts[1]})
        const allowance = await token.allowance(accounts[1], accounts[2])
        assertBigNumberEqual(allowance, '115792089237316195423570985008687907853269984665640564039457584007913129639935')
    })

    // EVENTS
    it('events: should fire Transfer event properly', async () => {
        const res = await token.transfer(accounts[2], tokenToRaw(2666), {from: accounts[1]})
        const transferLog = res.logs.find(
            element => element.event.match('Transfer') &&
                element.address.match(token.address)
        )
        assert.strictEqual(transferLog.args.from, accounts[1])
        // L2 ETH transfer also emits a transfer event
        assert.strictEqual(transferLog.args.to, accounts[2])
        assertBigNumberEqual(transferLog.args.value, tokenToRaw(2666))
    })

    it('events: should fire Approval event properly', async () => {
        const res = await token.approve(accounts[2], tokenToRaw(2666), {from: accounts[1]})
        const approvalLog = res.logs.find(element => element.event.match('Approval'))
        assert.strictEqual(approvalLog.args.owner, accounts[1])
        assert.strictEqual(approvalLog.args.spender, accounts[2])
        assertBigNumberEqual(approvalLog.args.value, tokenToRaw(2666))
    })
})