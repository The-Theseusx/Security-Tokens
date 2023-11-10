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

	function test_fuzz_canTransferFrom(address from, address to, uint256 amount, bytes memory data) public {
		vm.assume(to.code.length == 0);
		vm.assume(to > address(100));

		if (amount > 100e18 && amount < 1_000_000e18 && from != address(0)) {
			vm.startPrank(tokenAdmin);
			ERC1400MockToken.transfer(from, amount);
			vm.stopPrank();
		}

		if (uint160(from) > type(uint48).max && data.length <= 10) {
			vm.startPrank(from);
			ERC1400MockToken.approve(to, amount);
			vm.stopPrank();
		}

		if (data.length > 0) {
			data = prepareTransferSignature(TOKEN_TRANSFER_AGENT_PK, DEFAULT_PARTITION, from, to, amount, 0, 0);
		}

		vm.startPrank(to);
		(bool can, bytes memory reason, ) = ERC1400MockToken.canTransferFrom(from, to, amount, data);
		vm.stopPrank();

		if (keccak256(reason) == keccak256(INVALID_SENDER)) {
			assertFalse(can, "canTransferFrom should return false when from is address(0)");
			assertTrue(from == address(0), "ERC1400: transferFrom from the zero address should fail");
		} else if (keccak256(reason) == keccak256(INVALID_RECEIVER)) {
			assertFalse(can, "canTransferFrom should return false when to is address(0)");
			assertTrue(to == address(0), "ERC1400: transferFrom to the zero address should fail");
		} else if (keccak256(reason) == keccak256(TRANSFER_FAILURE)) {
			assertFalse(can, "canTransferFrom should return false when amount is 0");
			assertTrue(amount == 0, "ERC1400: zero amount transfer should fail");
		} else if (keccak256(reason) == keccak256(INSUFFICIENT_BALANCE)) {
			assertFalse(can, "canTransferFrom should return false when amount is greater than balance");
			assertTrue(
				ERC1400MockToken.balanceOfNonPartitioned(from) < amount,
				"ERC1400: insufficient balance transfer should fail"
			);
		} else if (keccak256(reason) == keccak256(INSUFFICIENT_ALLOWANCE)) {
			assertFalse(can, "canTransferFrom should return false when amount is greater than balance");
			assertTrue(
				(amount > ERC1400MockToken.allowance(from, to)),
				"ERC1400: insufficient allowance transfer should fail"
			);
		} else if (keccak256(reason) == keccak256(INVALID_DATA_OR_TOKEN_INFO)) {
			assertFalse(can, "canTransferFrom should return false when amount is greater than balance");
			assertTrue(data.length <= 10, "ERC1400: invalid data transfer should fail");
		} else {
			assertTrue(can, "canTransferFrom should return true when all conditions are met");
			assertEq(
				reason,
				TRANSFER_SUCCESS,
				"canTransferFrom should return empty reason when all conditions are met"
			);
		}
	}
}
