// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {IComptroller} from "./IComptroller.sol";
import {ICompoundBadDebtOracle} from "./ICompoundBadDebtOracle.sol";

/// @notice Contract that detects Compound bad debt.
contract CompoundBadDebtOracle is ICompoundBadDebtOracle {
    /// @notice reference to the comptroller contract
    address public immutable comptroller;

    /// @param _comptroller reference to the compound comptroller
    constructor(address _comptroller) {
        comptroller = _comptroller;
    }

    /// @notice returns true if the addresses are ordered from least to greatest and contain no duplicates
    /// @param addresses to check
    /// @return true if array contains no duplicates and the address are ordered
    /// returns false if the array has duplicates or is incorrectly ordered.
    function noDuplicatesAndOrdered(
        address[] memory addresses
    ) public pure returns (bool) {
        /// addresses
        unchecked {
            uint256 addressesLength = addresses.length;

            for (uint256 i = 0; i < addressesLength; i++) {
                if (i + 1 <= addressesLength - 1) {
                    if (addresses[i] >= addresses[i + 1]) {
                        return false;
                    }
                }
            }

            return true;
        }
    }

    /// @notice get the total bad debt for a given set of addresses
    /// @param addresses of users to find sum of bad debt
    /// @return totalBadDebt of all supplied users
    function getTotalBadDebt(
        address[] memory addresses
    ) public view returns (uint256 totalBadDebt) {
        uint256 accountsLength = addresses.length;

        for (uint256 i = 0; i < accountsLength; i++) {
            (, , uint256 badDebt) = IComptroller(comptroller)
                .getAccountLiquidity(addresses[i]);
            totalBadDebt += badDebt;
        }
    }
}
