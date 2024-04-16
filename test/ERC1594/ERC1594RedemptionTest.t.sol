//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1594BaseTest } from "./ERC1594BaseTest.t.sol";

abstract contract ERC1594RedemptionTest is ERC1594BaseTest {
    function testERC1594RedemptionShouldFailIfCallerNotAuthorized() public {
        vm.startPrank(notTokenAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, notTokenAdmin, mockERC1594.ERC1594_REDEEMER_ROLE()
            )
        );

        mockERC1594.redeemFrom(alice, 100, "");
    }

    function testERC1594RedemptionShouldFailIfAmountIsZero() public {
        vm.startPrank(tokenRedeemer);
        vm.expectRevert(ERC1594_ZeroAmount.selector);
        mockERC1594.redeemFrom(alice, 0, "");
        vm.stopPrank();
    }

    function testERC1594RedemptionShouldFailIfCallHasNotEnoughBalance() public {
        vm.startPrank(tokenRedeemer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20InsufficientBalance.selector, notTokenAdmin, mockERC1594.balanceOf(notTokenAdmin), 1000
            )
        );
        mockERC1594.redeemFrom(notTokenAdmin, 1000, "");
        vm.stopPrank();
    }

    function testERC1594RedemptionShouldPassIfUserHasEnoughBalanceAndCallerIsRedeemer() public {
        vm.startPrank(tokenRedeemer);
        vm.expectEmit(true, true, true, true);
        emit Redeemed(tokenRedeemer, alice, 1000, "");

        mockERC1594.redeemFrom(alice, 1000, "");
        vm.stopPrank();

        assertEq(
            mockERC1594.balanceOf(alice), ALICE_INITIAL_BALANCE - 1000, "Alice balance should be decreased by 1000"
        );
        assertEq(mockERC1594.totalSupply(), INITIAL_SUPPLY - 1000, "Total supply should be decreased by 1000");
    }

    function testERC1594RedemptionShouldPassIfCallerIsUserWithEnoughBalance() public {
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit Redeemed(alice, alice, 1000, "");

        mockERC1594.redeem(1000, "");
        vm.stopPrank();

        assertEq(
            mockERC1594.balanceOf(alice), ALICE_INITIAL_BALANCE - 1000, "Alice balance should be decreased by 1000"
        );
        assertEq(mockERC1594.totalSupply(), INITIAL_SUPPLY - 1000, "Total supply should be decreased by 1000");
    }
}
