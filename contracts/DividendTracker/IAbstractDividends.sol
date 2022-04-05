// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IAbstractDividends {
    /**
     * @dev Returns the total amount of dividends a given address is able to withdraw.
	 * @param account Address of a dividend recipient
	 * @return A uint256 representing the dividends `account` can withdraw
	 */
    function withdrawableDividendsOf(address account) external view returns (uint256);

    /**
       * @dev View the amount of funds that an address has withdrawn.
	 * @param account The address of a token holder.
	 * @return The amount of funds that `account` has withdrawn.
	 */
    function withdrawnDividendsOf(address account) external view returns (uint256);

    /**
     * @dev View the amount of funds that an address has earned in total.
	 * accumulativeFundsOf(account) = withdrawableDividendsOf(account) + withdrawnDividendsOf(account)
	 * = (pointsPerShare * balanceOf(account) + pointsCorrection[account]) / POINTS_MULTIPLIER
	 * @param account The address of a token holder.
	 * @return The amount of funds that `account` has earned in total.
	 */
    function cumulativeDividendsOf(address account) external view returns (uint256);

    /**
     * @dev Checks if an address is currently excluded from dividends
     */
    function isExcludedFromDividends(address account) external view returns (bool);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */

    /**
     * @dev This event emits when new funds are distributed
	 * @param by the address of the sender who distributed funds
	 * @param dividendsDistributed the amount of funds received for distribution
	 */
    event DividendsDistributed(address indexed by, uint256 dividendsDistributed);

    /**
     * @dev This event emits when distributed funds are withdrawn by a token holder.
	 * @param by the address of the receiver of funds
	 * @param fundsWithdrawn the amount of funds that were withdrawn
	 */
    event DividendsWithdrawn(address indexed by, uint256 fundsWithdrawn);

    event ExcludeAccountFromDividends(address account, bool enable);
}