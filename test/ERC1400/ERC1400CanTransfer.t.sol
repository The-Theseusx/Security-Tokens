//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import { console2 } from "forge-std/Test.sol";
import { ERC1400BaseTest } from "./ERC1400BaseTest.t.sol";

//solhint-disable func-name-mixedcase
abstract contract ERC1400CanTransferTest is ERC1400BaseTest {
	function testCanTransfer() public {}

	function test_fuzz_canTransfer(address to, uint256 amount, bytes memory data) public {
		vm.assume(to.code.length == 0);

		vm.startPrank(notTokenAdmin);
		(bool can, bytes memory reason, ) = ERC1400MockToken.canTransfer(to, amount, data);
		vm.stopPrank();

		if (to == address(0)) {
			assertFalse(can, "canTransfer should return false when to is address(0)");
			assertEq(reason, INVALID_RECEIVER, "ERC1400: transfer to the zero address should fail");
		} else if (amount == 0) {
			assertFalse(can, "canTransfer should return false when amount is 0");
			assertEq(reason, TRANSFER_FAILURE, "ERC1400: zero amount transfer should fail");
		} else if (amount > ERC1400MockToken.balanceOf(notTokenAdmin)) {
			assertFalse(can, "canTransfer should return false when amount is greater than balance");
			assertEq(reason, INSUFFICIENT_BALANCE, "ERC1400: insufficient balance transfer should fail");
		} else {
			assertTrue(can, "canTransfer should return true when all conditions are met");
			assertEq(reason, TRANSFER_SUCCESS, "canTransfer should return empty reason when all conditions are met");
		}
	}

	function testCanTransferContracts() public {
		vm.startPrank(tokenAdmin);
		(bool can, bytes memory reason, ) = ERC1400MockToken.canTransfer(
			address(nonERC1400ReceivableContract),
			1000e18,
			""
		);
		vm.stopPrank();

		assertFalse(
			can,
			"canTransfer should return false when to is a contract that does not implement ERC1400Receiver"
		);
		assertEq(reason, INVALID_RECEIVER, "ERC1400: transfer to non ERC1400Receiver implementer should fail");

		vm.startPrank(tokenAdmin);
		(can, reason, ) = ERC1400MockToken.canTransfer(address(ERC1400ReceivableContract), 1000e18, "");
		vm.stopPrank();

		assertTrue(can, "canTransfer should return true when to is a contract that implements ERC1400Receiver");
		assertEq(reason, TRANSFER_SUCCESS, "canTransfer should return empty reason when all conditions are met");
	}
}
