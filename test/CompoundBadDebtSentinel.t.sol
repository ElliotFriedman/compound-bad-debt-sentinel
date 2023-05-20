// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Common} from "./Common.sol";
import {CompoundBadDebtOracle} from "../src/CompoundBadDebtOracle.sol";

import "forge-std/Test.sol";

contract CompoundBadDebtOracleTest is Test {

    /// compound bad debt oracle
    CompoundBadDebtOracle public oracle;

    function setUp() public {
        oracle = new CompoundBadDebtOracle(Common.comptroller);
    }

    function testBadDebtDetected() public {
        /// zero cDAI and cUSDC balances to create bad debt
        deal(Common.CUSDC, Common.yearn, 0);
        deal(Common.CDAI, Common.yearn, 0);

        address[] memory user = new address[](1);
        user[0] = Common.yearn;

        assertTrue(oracle.getTotalBadDebt(user) > 10_000_000e18);
    }

    function testNoBadDebtDetected() public {
        address[] memory users = new address[](2);
        users[0] = Common.yearn; /// yearn is less than morpho, place it first to order list
        users[1] = Common.morpho;

        assertEq(oracle.getTotalBadDebt(users), 0);
    }
}