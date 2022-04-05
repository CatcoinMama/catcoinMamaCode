// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../Common/LowGasSafeMath.sol";
import "../Common/SafeCast.sol";
import "./IAbstractDividends.sol";
import "../Common/SafeMathInt.sol";
import "../Common/IterableMapping.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract AbstractDividends is Ownable, IAbstractDividends {
    using LowGasSafeMath for uint256;
    using SafeCast for uint128;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeMathInt for int256;
    using IterableMapping for IterableMapping.Map;

    /* ========  Constants  ======== */
    uint128 internal constant POINTS_MULTIPLIER = type(uint128).max;

    /* ========  Storage  ======== */
    uint256 public _totalDividendSupply;
    uint256 public totalDividendsDistributed;
    uint256 public pointsPerShare;

    uint256 public lastProcessedIndex;
    uint256 public claimWait;
    uint256 public minimumTokenBalanceForDividends;
    mapping(address => uint256) public lastClaimTimes;

    mapping(address => bool) private _isExcludedFromDividends;
    mapping(address => int256) internal pointsCorrection;
    mapping(address => uint256) private withdrawnDividends;
    IterableMapping.Map private tokenHoldersMap;

    /* ========  Public View Functions  ======== */

    function getNumberOfTokenHolders() external view returns (uint256) {
        return tokenHoldersMap.keys.length;
    }

    /**
     * @dev Returns the total amount of dividends a given address is able to withdraw.
   * @param account Address of a dividend recipient
   * @return A uint256 representing the dividends `account` can withdraw
   */
    function withdrawableDividendsOf(address account) public view override returns (uint256) {
        return cumulativeDividendsOf(account).sub(withdrawnDividends[account]);
    }

    /**
     * @notice View the amount of dividends that an address has withdrawn.
   * @param account The address of a token holder.
   * @return The amount of dividends that `account` has withdrawn.
   */
    function withdrawnDividendsOf(address account) public view override returns (uint256) {
        return withdrawnDividends[account];
    }

    /**
     * @notice View the amount of dividends that an address has earned in total.
   * @dev accumulativeFundsOf(account) = withdrawableDividendsOf(account) + withdrawnDividendsOf(account)
   * = (pointsPerShare * balanceOf(account) + pointsCorrection[account]) / POINTS_MULTIPLIER
   * @param account The address of a token holder.
   * @return The amount of dividends that `account` has earned in total.
   */
    function cumulativeDividendsOf(address account) public view override returns (uint256) {
        return pointsPerShare
        .mul(dividendBalanceOf(account))
        .toInt256()
        .add(pointsCorrection[account])
        .toUint256() / POINTS_MULTIPLIER;
    }
    /**
     * @dev Checks if an address is currently excluded from dividends
     */
    function isExcludedFromDividends(address account) public override view returns (bool) {
        return _isExcludedFromDividends[account];
    }

    /**
     * @dev Excludes an account from dividends
     */
    function excludeFromDividends(address account, bool exclude) internal {
        if (_isExcludedFromDividends[account] == exclude) return;
        _isExcludedFromDividends[account] = exclude;
        if (exclude) {
            _setBalance(account, 0);
            tokenHoldersMap.remove(account);
        }
        emit ExcludeAccountFromDividends(account, exclude);
    }

    /* ========  Dividend Utility Functions  ======== */

    /**
     * @notice Distributes dividends to token holders.
   * @dev It reverts if the total supply is 0.
   * It emits the `FundsDistributed` event if the amount to distribute is greater than 0.
   * About undistributed dividends:
   *   In each distribution, there is a small amount which does not get distributed,
   *   which is `(amount * POINTS_MULTIPLIER) % totalShares()`.
   *   With a well-chosen `POINTS_MULTIPLIER`, the amount of funds that are not getting
   *   distributed in a distribution can be less than 1 (base unit).
   */
    function _distributeDividends(uint256 amount) internal {
        uint256 shares = _totalDividendSupply;
        if (shares <= 0) return;

        if (amount > 0) {
            pointsPerShare = pointsPerShare.add(
                amount.mul(POINTS_MULTIPLIER) / shares
            );
            emit DividendsDistributed(msg.sender, amount);
            uint256 _totalDistributed = totalDividendsDistributed.add(amount);
            totalDividendsDistributed = _totalDistributed;
        }
    }

    /**
     * @notice Prepares collection of owed dividends
   * @dev It emits a `DividendsWithdrawn` event if the amount of withdrawn dividends is
   * greater than 0.
   */
    function _prepareCollect(address account) internal returns (uint256) {
        uint256 _withdrawableDividend = withdrawableDividendsOf(account);
        if (_withdrawableDividend > 0) {
            withdrawnDividends[account] = withdrawnDividends[account].add(_withdrawableDividend);
        }
        return _withdrawableDividend;
    }

    function _correctPointsForTransfer(address from, address to, uint256 shares) internal {
        int256 _magCorrection = pointsPerShare.mul(shares).toInt256();
        pointsCorrection[from] = pointsCorrection[from].add(_magCorrection);
        pointsCorrection[to] = pointsCorrection[to].sub(_magCorrection);
    }

    /**
     * @dev Increases or decreases the points correction for `account` by
   * `shares*pointsPerShare`.
   */
    function _correctPoints(address account, int256 shares) internal {
        pointsCorrection[account] = pointsCorrection[account]
        .add(shares.mul(int256(pointsPerShare)));
    }

    function dividendBalanceOf(address account) internal view returns (uint256) {
        return tokenHoldersMap.get(account);
    }

    function setDividendBalance(address account, uint256 newBalance) internal {
        if (_isExcludedFromDividends[account]) {
            return;
        }
        _setBalance(account, newBalance);
    }

    function _setBalance(address account, uint256 newBalance) internal {
        uint256 currentBalance = dividendBalanceOf(account);
        if (newBalance > currentBalance) {
            uint256 mintAmount = newBalance.sub(currentBalance);
            _mintDividends(account, mintAmount);
        } else if (newBalance < currentBalance) {
            uint256 burnAmount = currentBalance.sub(newBalance);
            _burnDividends(account, burnAmount);
        }
    }

    function _mintDividends(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalDividendSupply += amount;
        tokenHoldersMap.set(account, tokenHoldersMap.get(account) + amount);
        // ---------------------------------
        _correctPoints(account, - amount.toInt256());
    }

    function _burnDividends(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        uint256 accountBalance = tokenHoldersMap.get(account);
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
    unchecked {
        tokenHoldersMap.set(account, tokenHoldersMap.get(account) - amount);
    }
        _totalDividendSupply -= amount;
        // ---------------------------------
        _correctPoints(account, amount.toInt256());
    }

    // Dividend processing Dividend processing Dividend processing Dividend processing Dividend processing
    function updateMinimumForDividends(uint256 amount) external onlyOwner {
        require((amount >= 100_000 * 10 ** 18) && // 100K minimum
            (10_000_000_000 * 10 ** 18 >= amount) // 10B maximum
        , "should be 1M <= amount <= 10B");
        require(amount != minimumTokenBalanceForDividends, "value already assigned!");
        minimumTokenBalanceForDividends = amount;
    }

    function processAccountDividend(address account) external onlyOwner {
        _processAccount(account);
    }

    function _processAccount(address account) private returns (bool) {
        uint256 withdrawable = _prepareCollect(account);

        if (withdrawable > 0) {
            lastClaimTimes[account] = block.timestamp;
            _transferDividends(account, withdrawable);
            emit DividendsWithdrawn(account, withdrawable);
            return true;
        }

        return false;
    }

    function process(uint256 transfersPerBatch) internal returns (uint256, uint256, uint256) {
        uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;

        if (numberOfTokenHolders == 0) {
            return (0, 0, lastProcessedIndex);
        }

        uint256 _lastProcessedIndex = lastProcessedIndex;

        uint256 iterations = 0;
        uint256 claims = 0;
        uint256 maxIterations = Math.min(numberOfTokenHolders, transfersPerBatch + 1);

        while (iterations < maxIterations + 1) {
            _lastProcessedIndex++;

            if (_lastProcessedIndex >= tokenHoldersMap.keys.length) {
                _lastProcessedIndex = 0;
            }

            address account = tokenHoldersMap.keys[_lastProcessedIndex];

            if (canAutoClaim(lastClaimTimes[account])) {
                if (_processAccount(payable(account))) {
                    claims++;
                }
            }

            iterations++;
        }

        lastProcessedIndex = _lastProcessedIndex;

        return (iterations, claims, lastProcessedIndex);
    }

    // private
    function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
        if (lastClaimTime > block.timestamp) {
            return false;
        }

        return block.timestamp.sub(lastClaimTime) >= claimWait;
    }

    function _transferDividends(address recipient, uint256 amount) virtual internal returns (bool);
}