// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CompoundBadDebtOracle} from "../src/CompoundBadDebtOracle.sol";
import "forge-std/Test.sol";

contract CompoundBadDebtOracleTest is Test {

    /// compound flash mint folding yearn vault address
    address constant public yearn = 0x01d127D90513CCB6071F83eFE15611C4d9890668;

    /// compound morpho main address
    address constant public morpho = 0x8888882f8f843896699869179fB6E4f7e3B58888;

    /// USDC cToken
    address constant public CUSDC = 0x39AA39c021dfbaE8faC545936693aC917d5E7563;

    /// DAI cToken
    address constant public CDAI = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;

    /// compound comptroller address
    address constant public comptroller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;

    /// compound bad debt oracle
    CompoundBadDebtOracle public oracle;

    function setUp() public {
        oracle = new CompoundBadDebtOracle(comptroller);
    }

    function testBadDebtDetected() public {
        /// zero cDAI and cUSDC balances to create bad debt
        deal(CUSDC, yearn, 0);
        deal(CDAI, yearn, 0);

        address[] memory user = new address[](1);
        user[0] = yearn;

        assertTrue(oracle.getTotalBadDebt(user) > 10_000_000e18);
    }

    function testNoBadDebtDetected() public {
        address[] memory users = new address[](2);
        users[0] = yearn; /// yearn is less than morpho, place it first to order list
        users[1] = morpho;

        assertEq(oracle.getTotalBadDebt(users), 0);
    }
}