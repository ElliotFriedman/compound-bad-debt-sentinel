// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

/// @notice Contract that detects Compound bad debt.
interface ICompoundBadDebtOracle {
    /// @notice get the total bad debt for a given set of addresses
    /// @param addresses of users to find sum of bad debt
    /// @return totalBadDebt of all supplied users
    function getTotalBadDebt(
        address[] memory addresses
    ) external view returns (uint256 totalBadDebt);

    function noDuplicatesAndOrdered(
        address[] memory addresses
    ) external pure returns (bool);
}
