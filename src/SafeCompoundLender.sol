// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ICToken, ICEth} from "./IComptroller.sol";
import {CompoundBadDebtOracle} from "./CompoundBadDebtOracle.sol";

/// @notice Contract that supplies and redeems underlying to the compound protocol
/// Lending only. No borrowing.
/// You can borrow using the arbitrary action, but then in case of an unwind,
/// your position will remain open.
contract SafeCompoundLender is CompoundBadDebtOracle, Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;

    ///@notice set of whitelisted deposit addresses for withdrawal
    EnumerableSet.AddressSet private cTokens;

    /// @notice threshold for bad debt, when exceeded, the position can be permissionlessly unwound
    uint256 public badDebtThreshold;

    /// @notice address of the cETH contract
    address public constant ceth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;

    /// @notice emitted when the bad debt threshold is updated
    event BadDebtThresholdUpdated(uint256 newThreshold, uint256 oldThreshold);

    /// Construct the SafeCompoundLender
    /// @param _comptroller reference to the compound comptroller
    constructor(address _comptroller, uint256 _badDebtThreshold) CompoundBadDebtOracle(_comptroller) {
        badDebtThreshold = _badDebtThreshold;
    }

    /// @notice helper function to approve a cToken to spend the underlying
    /// @param cToken address of the cToken to approve
    /// @param amount amount of underlying to approve
    function _approveCToken(address cToken, uint256 amount) private {
        IERC20 underlying = IERC20(ICToken(cToken).underlying());
        underlying.approve(cToken, amount);
    }

    /// @notice approve a cToken to spend the underlying
    function approveCToken(address cToken) external onlyOwner {
        _approveCToken(cToken, type(uint256).max);
    }

    /// @notice supply underlying to the compound protocol
    /// callable only by owner
    /// doesn't work for cETH
    /// @param cToken address of the cToken to supply
    /// @param amount amount of underlying to supply
    function supply(address cToken, uint256 amount) external onlyOwner {
        require(cToken != ceth, "ceth disallowed");
        /// if not added yet, max approve underlying to be spent by cToken
        if (cTokens.add(cToken)) {
            _approveCToken(cToken, type(uint256).max);
        }

        require(ICToken(cToken).mint(amount) == 0, "mint failed");
    }

    /// @notice supply eth to the compound protocol
    /// callable only by owner
    /// only works for cETH
    /// @param cToken address of the cToken to supply
    function supplyEth(address cToken) external payable onlyOwner {
        require(cToken == ceth, "only ceth");
        cTokens.add(cToken); /// no-op if already added
        ICEth(cToken).mint{value: msg.value}();
    }
    
    /// @notice redeem cTokens for underlying
    /// callable only by owner
    /// @param cToken address of the cToken to redeem
    /// @param amountUnderlying amount of underlying to redeem
    function redeem(address cToken, uint256 amountUnderlying) external onlyOwner {
        require(ICToken(cToken).redeemUnderlying(amountUnderlying) == 0, "redeem failed");
    }

    function redeemAll(address cToken) external onlyOwner {
        uint256 balance = ICToken(cToken).balanceOf(address(this));
        require(ICToken(cToken).redeem(balance) == 0, "redeem failed");
        cTokens.remove(cToken); /// remove cToken from set
    }

    /// @notice owner can call arbitrary functions on any contract with any amount of eth
    /// this function is used to transfer tokens out of the contract
    /// @param target address of the contract to call
    /// @param value amount of eth to send
    /// @param data calldata to send
    function arbitraryAction(address target, uint256 value, bytes calldata data) external onlyOwner {
        (bool success, bytes memory returnData) = target.call{value: value}(data);
        require(success, string(returnData));
    }

    /// @notice owner sets the bad debt threshold
    /// any position with bad debt above this threshold can be unwound
    /// @param _badDebtThreshold new bad debt threshold
    function setBadDebtThreshold(uint256 _badDebtThreshold) external onlyOwner {
        badDebtThreshold = _badDebtThreshold;
    }

    /// @notice permissionless function to unwind a position when the bad debt threshold is exceeded
    /// @param addresses array of addresses whose cumulative bad debt is over the bad debt threshold
    function unwindPosition(address[] memory addresses) external {
        require(noDuplicatesAndOrdered(addresses), "invalid address order");
        require(getTotalBadDebt(addresses) >= badDebtThreshold, "bad debt below threshold");
        require(cTokens.length() > 0, "no position to unwind");

        for (uint256 i = 0; i < cTokens.length(); i++) {     
            address cToken = cTokens.at(i);
            ICToken(cToken).accrueInterest(); /// accrue before getting balance of underlying
            uint256 balance = ICToken(cToken).balanceOfUnderlying(address(this));
            uint256 actualCtokenBalance;
            if (cToken == ceth) {
                actualCtokenBalance = address(ceth).balance;
            } else {
                address underlying = ICToken(cToken).underlying();
                actualCtokenBalance = IERC20(underlying).balanceOf(address(cToken));
            }

            /// if no liquidity, or no balance, do not redeem
            if (balance != 0 && actualCtokenBalance != 0) {
                require(
                    ICToken(cToken).redeemUnderlying(
                        /// handle edge case where cToken liquidity is less than user is owed
                        Math.min(
                            balance,
                            actualCtokenBalance
                        )
                    ) == 0,
                    "redeem failed"
                );
            }
        }
    }

    /// function to receive payment on cEth redemption
    receive() external payable {}
}
