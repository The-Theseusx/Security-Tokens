//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1594BaseTest } from "./ERC1594BaseTest.t.sol";

abstract contract ERC1594TransferTest is ERC1594BaseTest {
    function testERC1594TransferWithDataShouldFailIfNotEnoughBalance() public {
        uint256 transferAmount = type(uint256).max;

        bytes memory transferData = abi.encodePacked("Sample transfer data");

        vm.startPrank(notTokenAdmin);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, notTokenAdmin, 0, transferAmount));
        mockERC1594.transferWithData(bob, transferAmount, transferData);
        vm.stopPrank();
    }

    function testERC1594TransferWithData() public {
        uint256 transferAmount = 1000e18;

        bytes memory transferData = abi.encodePacked("Sample transfer data");

        uint256 aliceBalancePrior = mockERC1594.balanceOf(alice);
        uint256 bobBalancePrior = mockERC1594.balanceOf(bob);

        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);

        emit TransferWithData(alice, bob, transferAmount, transferData);
        mockERC1594.transferWithData(bob, transferAmount, transferData);

        vm.stopPrank();

        uint256 aliceBalancePost = mockERC1594.balanceOf(alice);
        uint256 bobBalancePost = mockERC1594.balanceOf(bob);

        assertEq(
            aliceBalancePost, aliceBalancePrior - transferAmount, "Alice balance should decrease by transfer amount"
        );
        assertEq(bobBalancePost, bobBalancePrior + transferAmount, "Bob balance should increase by transfer amount");
    }

    function testERC1594TransferFromWithDataShouldFailIfNotEnoughBalance() public {
        uint256 transferAmount = type(uint256).max;

        bytes memory transferData =
            prepareTransferSignature(TOKEN_TRANSFER_AGENT_PK, notTokenAdmin, bob, transferAmount, 0, 0);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, notTokenAdmin, 0, transferAmount));
        mockERC1594.transferFromWithData(notTokenAdmin, bob, transferAmount, transferData);
        vm.stopPrank();
    }

    function testERC1594TransferFromWithDataShouldFailIfInvalidSigner() public {
        uint256 transferAmount = 1000e18;

        ///@notice This is the private key of the account that is not the token transfer agent
        bytes memory transferData = prepareTransferSignature(NOT_ADMIN_PK, alice, bob, transferAmount, 0, 0);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC1594_InvalidSignatureData.selector));
        mockERC1594.transferFromWithData(alice, bob, transferAmount, transferData);
        vm.stopPrank();
    }

    function testERC1594TransferFromWithDataShouldFailIfInvalidNonceUsed() public {
        uint256 transferAmount = 1000e18;

        uint256 badNonce = 10;
        bytes memory transferData =
            prepareTransferSignature(TOKEN_TRANSFER_AGENT_PK, alice, bob, transferAmount, badNonce, 0);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC1594_InvalidSignatureData.selector));
        mockERC1594.transferFromWithData(alice, bob, transferAmount, transferData);
        vm.stopPrank();
    }

    function testERC1594TransferFromWithDataShouldFailIfSIgnatureExpires() public {
        uint256 transferAmount = 1000e18;

        bytes memory transferData =
            prepareTransferSignature(TOKEN_TRANSFER_AGENT_PK, alice, bob, transferAmount, 0, 2 minutes);

        ///@notice skip time to make the signature expire
        skip(5 minutes);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC1594_ExpiredSignature.selector));
        mockERC1594.transferFromWithData(alice, bob, transferAmount, transferData);
        vm.stopPrank();
    }

    function testERC1594TransferFromWithData() public {
        uint256 transferAmount = 1000e18;

        bytes memory transferData = prepareTransferSignature(TOKEN_TRANSFER_AGENT_PK, alice, bob, transferAmount, 0, 0);

        uint256 aliceBalancePrior = mockERC1594.balanceOf(alice);
        uint256 bobBalancePrior = mockERC1594.balanceOf(bob);

        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);

        emit TransferWithData(alice, bob, transferAmount, transferData);
        mockERC1594.transferFromWithData(alice, bob, transferAmount, transferData);

        vm.stopPrank();

        uint256 aliceBalancePost = mockERC1594.balanceOf(alice);
        uint256 bobBalancePost = mockERC1594.balanceOf(bob);

        assertEq(
            aliceBalancePost, aliceBalancePrior - transferAmount, "Alice balance should decrease by transfer amount"
        );
        assertEq(bobBalancePost, bobBalancePrior + transferAmount, "Bob balance should increase by transfer amount");
    }
}
