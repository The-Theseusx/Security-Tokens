//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console2 } from "forge-std/Test.sol";
import { ERC1400BaseTest } from "./ERC1400BaseTest.t.sol";

//solhint-disable func-name-mixedcase
abstract contract ERC1400CanTransferTest is ERC1400BaseTest {
    function test_fuzz_canTransferByPartition(
        address from,
        address to,
        bytes32 partition,
        uint256 amount,
        bytes memory data
    ) public {
        vm.assume(from.code.length == 0);
        vm.assume(to.code.length == 0);

        if (partition < SHARED_SPACES_PARTITION) {
            partition = SHARED_SPACES_PARTITION;
        }

        if (amount > 100e18 && from != address(0)) {
            amount = ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, alice);
            vm.startPrank(alice);
            ERC1400MockToken.transferByPartition(SHARED_SPACES_PARTITION, from, amount, "");
            vm.stopPrank();
        }

        if (from != address(0) && partition == SHARED_SPACES_PARTITION) {
            vm.startPrank(from);
            ERC1400MockToken.approveByPartition(SHARED_SPACES_PARTITION, to, amount);
            vm.stopPrank();
        }

        if (data.length > 0) {
            data = prepareTransferSignature(TOKEN_TRANSFER_AGENT_PK, SHARED_SPACES_PARTITION, from, to, amount, 0, 0);
        }

        vm.startPrank(to);
        (bytes memory statusCode,,) = ERC1400MockToken.canTransferByPartition(from, to, partition, amount, data);
        vm.stopPrank();

        if (keccak256(statusCode) == keccak256(INVALID_SENDER)) {
            console2.log("INVALID_SENDER");
            assertTrue(from == address(0), "ERC1400: transferByPartition from the zero address should fail");
        } else if (keccak256(statusCode) == keccak256(INVALID_RECEIVER)) {
            console2.log("INVALID_RECEIVER");
            assertTrue(to == address(0), "ERC1400: transferByPartition to the zero address should fail");
        } else if (keccak256(statusCode) == keccak256(TRANSFER_FAILURE)) {
            console2.log("TRANSFER_FAILURE");
            bool validTransferFailure;
            if (amount == 0 || partition != SHARED_SPACES_PARTITION) validTransferFailure = true;
            assertTrue(validTransferFailure, "ERC1400: zero amount transferByPartition should fail");
        } else if (keccak256(statusCode) == keccak256(INSUFFICIENT_BALANCE)) {
            console2.log("INSUFFICIENT_BALANCE");
            assertTrue(
                ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, from) < amount,
                "ERC1400: insufficient balance transferByPartition should fail"
            );
        } else if (keccak256(statusCode) == keccak256(INSUFFICIENT_ALLOWANCE)) {
            console2.log("INSUFFICIENT_ALLOWANCE");
            assertTrue(
                (amount > ERC1400MockToken.allowanceByPartition(SHARED_SPACES_PARTITION, from, to)),
                "ERC1400: insufficient allowance transferByPartition should fail"
            );
        } else if (keccak256(statusCode) == keccak256(INVALID_DATA_OR_TOKEN_INFO)) {
            console2.log("INVALID_DATA_OR_TOKEN_INFO");
            assertTrue(data.length <= 10, "ERC1400: invalid data transferByPartition should fail");
        } else {
            console2.log("SUCCESS");
            assertEq(
                statusCode,
                TRANSFER_SUCCESS,
                "canTransferByPartition should return empty reason when all conditions are met"
            );
        }
    }

    function testCanTransferByPartitionContracts() public {
        vm.startPrank(alice);
        ERC1400MockToken.approveByPartition(SHARED_SPACES_PARTITION, address(ERC1400ReceivableContract), 1000e18);
        ERC1400MockToken.approveByPartition(SHARED_SPACES_PARTITION, address(nonERC1400ReceivableContract), 1000e18);
        vm.stopPrank();

        vm.startPrank(address(nonERC1400ReceivableContract));
        (bytes memory statusCode,,) = ERC1400MockToken.canTransferByPartition(
            alice, address(nonERC1400ReceivableContract), SHARED_SPACES_PARTITION, 1000e18, ""
        );

        assertEq(
            keccak256(statusCode),
            keccak256(INVALID_RECEIVER),
            "ERC1400: canTransferByPartition to non ERC1400Receiver implementer should return invalid receiver"
        );

        vm.startPrank(address(ERC1400ReceivableContract));
        (statusCode,,) = ERC1400MockToken.canTransferByPartition(
            alice, address(ERC1400ReceivableContract), SHARED_SPACES_PARTITION, 1000e18, ""
        );
        vm.stopPrank();

        assertEq(
            keccak256(statusCode), keccak256(TRANSFER_SUCCESS), "canTransferByPartition should return can transfer"
        );
    }

    function test_fuzz_canTransfer(address to, uint256 amount, bytes memory data) public {
        vm.assume(to.code.length == 0);

        vm.startPrank(notTokenAdmin);
        (bool can, bytes memory reason,) = ERC1400MockToken.canTransfer(to, amount, data);
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
        (bool can, bytes memory reason,) =
            ERC1400MockToken.canTransfer(address(nonERC1400ReceivableContract), 1000e18, "");
        vm.stopPrank();

        assertFalse(
            can, "canTransfer should return false when to is a contract that does not implement ERC1400Receiver"
        );
        assertEq(reason, INVALID_RECEIVER, "ERC1400: transfer to non ERC1400Receiver implementer should fail");

        vm.startPrank(tokenAdmin);
        (can, reason,) = ERC1400MockToken.canTransfer(address(ERC1400ReceivableContract), 1000e18, "");
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
        (bool can, bytes memory reason,) = ERC1400MockToken.canTransferFrom(from, to, amount, data);
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
                ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, from) < amount,
                "ERC1400: insufficient balance transfer should fail"
            );
        } else if (keccak256(reason) == keccak256(INSUFFICIENT_ALLOWANCE)) {
            assertFalse(can, "canTransferFrom should return false when amount is greater than balance");
            assertTrue(
                (amount > ERC1400MockToken.allowance(from, to)), "ERC1400: insufficient allowance transfer should fail"
            );
        } else if (keccak256(reason) == keccak256(INVALID_DATA_OR_TOKEN_INFO)) {
            assertFalse(can, "canTransferFrom should return false when amount is greater than balance");
            assertTrue(data.length <= 10, "ERC1400: invalid data transfer should fail");
        } else {
            assertTrue(can, "canTransferFrom should return true when all conditions are met");
            assertEq(reason, TRANSFER_SUCCESS, "canTransferFrom should return empty reason when all conditions are met");
        }
    }

    function testCanTransferFromContracts() public {
        vm.startPrank(tokenAdmin);
        ERC1400MockToken.approve(address(ERC1400ReceivableContract), 1000e18);
        ERC1400MockToken.approve(address(nonERC1400ReceivableContract), 1000e18);
        vm.stopPrank();

        vm.startPrank(address(nonERC1400ReceivableContract));
        (bool can, bytes memory reason,) =
            ERC1400MockToken.canTransferFrom(tokenAdmin, address(nonERC1400ReceivableContract), 1000e18, "");

        assertFalse(
            can, "canTransferFrom should return false when to is a contract that does not implement ERC1400Receiver"
        );
        assertEq(reason, INVALID_RECEIVER, "ERC1400: transfer to non ERC1400Receiver implementer should fail");

        vm.startPrank(address(ERC1400ReceivableContract));
        (can, reason,) = ERC1400MockToken.canTransferFrom(tokenAdmin, address(ERC1400ReceivableContract), 1000e18, "");
        vm.stopPrank();

        assertTrue(can, "canTransfer should return true when to is a contract that implements ERC1400Receiver");
        assertEq(reason, TRANSFER_SUCCESS, "canTransfer should return empty reason when all conditions are met");
    }

    function test_fuzz_canTransfer(bytes32 partition, address from, address to, uint256 amount, bytes memory data)
        public
    {
        vm.assume(from.code.length == 0);
        vm.assume(to.code.length == 0);

        if (partition < SHARED_SPACES_PARTITION && partition != DEFAULT_PARTITION) {
            partition = SHARED_SPACES_PARTITION;
        }

        if (amount > 100e18 && from != address(0)) {
            if (partition == DEFAULT_PARTITION) {
                amount = ERC1400MockToken.balanceOf(tokenAdmin);
                vm.startPrank(tokenAdmin);
                ERC1400MockToken.transfer(from, amount);
                vm.stopPrank();
            } else {
                amount = ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, alice);
                vm.startPrank(alice);
                ERC1400MockToken.transferByPartition(SHARED_SPACES_PARTITION, from, amount, "");
                vm.stopPrank();
            }
        }

        if (from != address(0)) {
            vm.startPrank(from);
            partition == DEFAULT_PARTITION
                ? ERC1400MockToken.approve(to, amount)
                : ERC1400MockToken.approveByPartition(SHARED_SPACES_PARTITION, to, amount);
            vm.stopPrank();
        }

        if (data.length > 0) {
            data = prepareTransferSignature(TOKEN_TRANSFER_AGENT_PK, partition, from, to, amount, 0, 0);
        }

        vm.startPrank(to);
        // (bool can, string memory reason) = ERC1400MockToken.canTransfer(
        // 	partition,
        // 	from,
        // 	to,
        // 	amount,
        // 	validateData,
        // 	data
        // );
        // if (!can) {
        // 	if (partition == DEFAULT_PARTITION) {
        // 		if (from != address(0) && to != address(0)) {
        // 			if (from != to) {}
        // 		}
        // 	}
        // }

        ///@dev necessary to test this?? Remove canTransfer(partition, from, to, amount, validateData, data) altogether??

        // console2.log("can: ", can);
        // console2.log("reason: ", reason);
    }
}
