//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1594BaseTest } from "./ERC1594BaseTest.t.sol";

abstract contract ERC1594IssuanceTest is ERC1594BaseTest {
    function testERC1594IssuanceShouldFailIfCallerNotIssuer() public {
        vm.startPrank(notTokenAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, notTokenAdmin, mockERC1594.ERC1594_ISSUER_ROLE()
            )
        );
        mockERC1594.issue(alice, 100, "");
    }

    function testERC1594IssuanceShouldFailIfRecipientIsZeroAddress() public {
        vm.startPrank(tokenIssuer);
        vm.expectRevert(abi.encodeWithSelector(ERC1594_InvalidReceiver.selector, ZERO_ADDRESS));
        mockERC1594.issue(ZERO_ADDRESS, 100, "");
        vm.stopPrank();
    }

    function testERC1594IssuanceShouldFailIfIssuanceDisabled() public {
        vm.startPrank(tokenAdmin);
        mockERC1594.disableIssuance();
        vm.stopPrank();

        vm.startPrank(tokenIssuer);
        vm.expectRevert(ERC1594_IssuanceDisabled.selector);
        mockERC1594.issue(alice, 100, "");
        vm.stopPrank();
    }

    function testERC1594IssuanceShouldFailIfAmountIsZero() public {
        vm.startPrank(tokenIssuer);
        vm.expectRevert(ERC1594_ZeroAmount.selector);
        mockERC1594.issue(alice, 0, "");
        vm.stopPrank();
    }

    function testERC1594IssuanceShouldIssueTokensToUser() public {
        vm.startPrank(tokenIssuer);

        vm.expectEmit(true, true, true, true);
        emit Issued(tokenIssuer, bob, 100, "");

        uint256 bobBalancePrior = mockERC1594.balanceOf(bob);

        mockERC1594.issue(bob, 100, "");

        vm.stopPrank();

        assertEq(mockERC1594.balanceOf(bob), bobBalancePrior + 100, "alice should have 100 tokens more");
        assertEq(mockERC1594.totalSupply(), INITIAL_SUPPLY + 100, "total supply should be increased by 100");
    }
}
