// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

contract MockComptroller {
    uint256 public badDebt;

    function setBadDebt(uint256 _badDebt) external {
        badDebt = _badDebt;
    }

    function getAccountLiquidity(address) external view returns (uint256, uint256, uint256) {
        return (0, 0, badDebt);
    }
}