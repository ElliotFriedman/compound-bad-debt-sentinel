// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {Common} from "./Common.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCompoundLender} from "../src/SafeCompoundLender.sol";
import {CompoundBadDebtOracle} from "../src/CompoundBadDebtOracle.sol";
import {ICToken, ICEth, IComptroller} from "./../src/IComptroller.sol";

import "forge-std/Test.sol";

contract SafeCompoundLenderTest is Test {
    /// safe compound lender
    SafeCompoundLender public lender;

    uint256 public constant badDebtThreshold = 10_000_000e18;

    uint256 public constant usdcAmount = 1_000_000e6;

    uint256 public constant daiAmount = 1_000_000e18;

    function setUp() public {
        lender = new SafeCompoundLender(Common.comptroller, badDebtThreshold);
        deal(Common.USDC, address(lender), usdcAmount);
        deal(Common.DAI, address(lender), daiAmount);

        vm.label(Common.USDC, "USDC");
        vm.label(Common.DAI, "DAI");
        vm.label(Common.CUSDC, "CUSDC");
        vm.label(Common.CDAI, "CDAI");
        vm.label(Common.CETH, "CETH");
        vm.label(Common.comptroller, "comptroller");
        vm.label(Common.yearn, "yearn");
        vm.label(address(lender), "lender");
    }

    function testBadDebtDetected() public {
        /// zero cDAI and cUSDC balances to create bad debt
        deal(Common.CUSDC, Common.yearn, 0);
        deal(Common.CDAI, Common.yearn, 0);

        address[] memory user = new address[](1);
        user[0] = Common.yearn;

        assertTrue(lender.getTotalBadDebt(user) > 10_000_000e18);
    }

    function testNoBadDebtDetected() public {
        address[] memory users = new address[](2);
        users[0] = Common.yearn; /// yearn is less than morpho, place it first to order list
        users[1] = Common.morpho;

        assertEq(lender.getTotalBadDebt(users), 0);
    }

    function testSupplyUsdc() public {
        assertEq(IERC20(Common.CUSDC).balanceOf(address(lender)), 0);

        lender.supply(Common.CUSDC, usdcAmount);

        assertEq(IERC20(Common.USDC).balanceOf(address(this)), 0);
        assertTrue(IERC20(Common.CUSDC).balanceOf(address(lender)) > 0);
    }

    function testSupplyDai() public {
        assertEq(IERC20(Common.CDAI).balanceOf(address(lender)), 0);

        lender.supply(Common.CDAI, daiAmount);

        assertEq(IERC20(Common.DAI).balanceOf(address(this)), 0);
        assertTrue(IERC20(Common.CDAI).balanceOf(address(lender)) > 0);
    }

    function testRedeemDai() public {
        testSupplyDai();

        assertEq(IERC20(Common.DAI).balanceOf(address(lender)), 0);
        assertTrue(IERC20(Common.CDAI).balanceOf(address(lender)) > 0);

        /// redeem all
        lender.redeem(Common.CDAI, ICToken(Common.CDAI).balanceOfUnderlying(address(lender)));

        assertApproxEqAbs(
            IERC20(Common.DAI).balanceOf(address(lender)),
            daiAmount,
            1e10, /// 10,000,000,000 wei of DAI can be lost in rounding
            "incorrect dai amount"
        );
        assertTrue(IERC20(Common.CDAI).balanceOf(address(lender)) < 10);
    }

    function testRedeemAllDai() public {
        testSupplyDai();
        
        assertEq(IERC20(Common.DAI).balanceOf(address(lender)), 0);
        assertTrue(IERC20(Common.CDAI).balanceOf(address(lender)) > 0);
        
        /// redeem all
        lender.redeemAll(Common.CDAI);
        
        assertApproxEqAbs(IERC20(Common.DAI).balanceOf(address(lender)), daiAmount, 1e18, "incorrect dai amount"); /// 1 wei of DAI is lost in rounding
        assertTrue(IERC20(Common.CDAI).balanceOf(address(lender)) < 10);
    }

    function testAnyUserUnwindsPositionWhenBadDebtPresent(address caller) public {
        vm.assume(caller != address(this));

        testSupplyDai(); /// supply dai
        testBadDebtDetected(); /// create bad debt

        address[] memory addresses = new address[](1);
        addresses[0] = Common.yearn;

        vm.prank(caller);
        lender.unwindPosition(addresses);

        assertApproxEqAbs(
            IERC20(Common.DAI).balanceOf(address(lender)),
            daiAmount,
            1e10, /// 10,000,000,000 wei of DAI can be lost in rounding
            "incorrect dai amount"
        );
        assertTrue(IERC20(Common.CDAI).balanceOf(address(lender)) < 10);
    }

    function testSupplyCethOnRegularSupplyFails() public {
        vm.expectRevert("ceth disallowed");
        lender.supply(Common.CETH, 1_000_000e18);
    }

    function testSupplyNonEthToEthFails() public {
        vm.expectRevert("only ceth");
        lender.supplyEth(Common.CUSDC);
    }

    /// ------------ ACL Tests ------------

    function test_setBadDebtThreshold_notOwner(address caller) public {
        _prankAndExpectRevertNotOwner(caller, "Ownable: caller is not the owner");
        lender.setBadDebtThreshold(0);
    }

    function test_approveCToken(address caller) public {
        _prankAndExpectRevertNotOwner(caller, "Ownable: caller is not the owner");
        lender.approveCToken(Common.CUSDC);
    }

    function test_supply(address caller) public {
        _prankAndExpectRevertNotOwner(caller, "Ownable: caller is not the owner");
        lender.supply(Common.CUSDC, 0);
    }

    function test_redeem(address caller) public {
        _prankAndExpectRevertNotOwner(caller, "Ownable: caller is not the owner");
        lender.redeem(Common.CUSDC, 0);
    }

    function test_redeemAll(address caller) public {
        _prankAndExpectRevertNotOwner(caller, "Ownable: caller is not the owner");
        lender.redeemAll(Common.CUSDC);
    }

    function test_supplyEth(address caller) public {
        _prankAndExpectRevertNotOwner(caller, "Ownable: caller is not the owner");
        lender.supplyEth(Common.CETH);
    }
    
    function _prankAndExpectRevertNotOwner(address caller, string memory message) private {
        vm.assume(caller != address(this));
        vm.prank(caller);
        vm.expectRevert(bytes(message));
    }
}
