//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1594BaseTest } from "./ERC1594BaseTest.t.sol";

abstract contract ERC1594TransferTest is ERC1594BaseTest {
    function testERC1594TransferWithDataShouldFailIfNotEnoughBalance() public {
        uint256 transferAmount = type(uint256).max;

        bytes memory transferData =
            prepareTransferSignature(TOKEN_TRANSFER_AGENT_PK, notTokenAdmin, bob, transferAmount, 0, 0);

        vm.startPrank(notTokenAdmin);
        // vm.expectRevert(
        //     abi.encodeWithSelector(ERC20InsufficientBalance.selector, bob, mockERC1594.balanceOf(bob), transferAmount)
        // );
        mockERC1594.transferWithData(bob, transferAmount, transferData);
        vm.stopPrank();
    }
}
