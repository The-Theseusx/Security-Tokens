//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import { Test } from "forge-std/Test.sol";
import { ERC1400 } from "../../src/ERC1400/ERC1400.sol";
import { ERC1400BaseTest } from "./ERC1400BaseTest.t.sol";

abstract contract ERC1400TransferTest is ERC1400BaseTest {
	function testShouldNotTransferWithInsufficientBalance() public {
		///@notice alice has no tokens on default partition.
		vm.startPrank(alice);
		vm.expectRevert("ERC1400: insufficient balance");
		ERC1400MockToken.transfer(bob, 1000e18);
		vm.stopPrank();
	}

	function testShouldNotTransferToZeroAddress() public {
		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400: transfer to zero address");
		ERC1400MockToken.transfer(address(0), 1000e18);
		vm.stopPrank();
	}

	function testShouldNotTransferZeroAmount() public {
		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400: zero amount");
		ERC1400MockToken.transfer(bob, 0);
		vm.stopPrank();
	}

	function testShouldNotTransferToNonERC1400ReceiverImplementerContract() public {
		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400: transfer to non ERC1400Receiver implementer");
		ERC1400MockToken.transfer(address(nonERC1400ReceivableContract), 1000e18);
		vm.stopPrank();
	}

	function testShouldTransferToERC1400ReceiverImplementerContract() public {
		vm.startPrank(tokenAdmin);
		vm.expectEmit(true, true, true, true);
		emit Transfer(tokenAdmin, address(ERC1400ReceivableContract), 1000e18);
		ERC1400MockToken.transfer(address(ERC1400ReceivableContract), 1000e18);
		vm.stopPrank();
	}

	function testTransferTokensOnDefaultPartition() public {
		uint256 tokenAdminBalancePrior = ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, tokenAdmin);

		vm.startPrank(tokenAdmin);
		vm.expectEmit(true, true, true, true);
		emit Transfer(tokenAdmin, bob, 1000e18);
		ERC1400MockToken.transfer(bob, 1000e18);
		vm.stopPrank();

		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, bob),
			1000e18,
			"Bob's default partition balance should be 1000e18"
		);
		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, tokenAdmin),
			tokenAdminBalancePrior - 1000e18,
			"Admin's balance should reduce by 1000e18"
		);
	}

	function testShouldNotTransferWithDataWhenInvalidSigner() public {
		///@notice invalid signer used
		bytes memory transferData = prepareTransferSignature(999, DEFAULT_PARTITION, tokenAdmin, alice, 100e18, 0, 0);

		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400: invalid data");
		ERC1400MockToken.transferWithData(alice, 100e18, transferData);
		vm.stopPrank();
	}

	function testShoulNotTransferWithDataWhenNoData() public {
		vm.startPrank(tokenAdmin);
		vm.expectRevert();
		ERC1400MockToken.transferWithData(alice, 100e18, "");
		vm.stopPrank();
	}

	function testShouldNotTransferWithDataWhenWrongNonce() public {
		///@notice wrong nonce used
		bytes memory transferData = prepareTransferSignature(
			TOKEN_TRANSFER_AGENT_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			alice,
			100e18,
			15,
			0
		);

		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400: invalid data");
		ERC1400MockToken.transferWithData(alice, 100e18, transferData);
		vm.stopPrank();
	}

	function testShouldNotTransferWithDataWhenNonceReused() public {
		bytes memory transferData = prepareTransferSignature(
			TOKEN_TRANSFER_AGENT_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			alice,
			100e18,
			0,
			0
		);

		vm.startPrank(tokenAdmin);
		ERC1400MockToken.transferWithData(alice, 100e18, transferData);
		vm.stopPrank();

		bytes memory transferData2 = prepareTransferSignature(
			TOKEN_TRANSFER_AGENT_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			bob,
			100e18,
			0,
			0
		);

		vm.startPrank(tokenAdmin);
		ERC1400MockToken.transferWithData(bob, 100e18, transferData2);
		vm.stopPrank();

		///@dev reusing nonce 1.
		bytes memory transferData3 = prepareTransferSignature(
			TOKEN_TRANSFER_AGENT_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			alice,
			100e18,
			1,
			0
		);

		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400: invalid data");
		ERC1400MockToken.transferWithData(alice, 100e18, transferData3);
		vm.stopPrank();
	}

	function testShouldNotTransferWithDataWhenExpiredSignature() public {
		skip(5 minutes);
		///@notice expired signature used
		bytes memory transferData = prepareTransferSignature(
			TOKEN_TRANSFER_AGENT_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			alice,
			100e18,
			0,
			100
		);

		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400: Expired signature");
		ERC1400MockToken.transferWithData(alice, 100e18, transferData);
		vm.stopPrank();
	}

	function testShouldTransferWithData() public {
		bytes memory transferData = prepareTransferSignature(
			TOKEN_TRANSFER_AGENT_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			alice,
			100e18,
			0,
			0
		);

		uint256 tokenAdminBalancePrior = ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, tokenAdmin);

		vm.startPrank(tokenAdmin);
		vm.expectEmit(true, true, true, true);
		emit TransferWithData(tokenTransferAgent, tokenAdmin, alice, 100e18, transferData);
		ERC1400MockToken.transferWithData(alice, 100e18, transferData);
		vm.stopPrank();

		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, alice),
			100e18,
			"Alice's balance should be 100e18"
		);

		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, tokenAdmin),
			tokenAdminBalancePrior - 100e18,
			"Admin's balance should reduce by 100e18"
		);
	}

	function testTransferByPartitionShouldNotTransferWithInsufficientBalance() public {
		///@notice notTokenAdmin has no tokens on shared spaces partition.
		vm.startPrank(notTokenAdmin);
		vm.expectRevert("ERC1400: insufficient balance");
		ERC1400MockToken.transferByPartition(SHARED_SPACES_PARTITION, bob, 1000e18, "");
		vm.stopPrank();
	}

	function testTransferByPartitionShouldNotTransferToZeroAddress() public {
		vm.startPrank(alice);
		vm.expectRevert("ERC1400: transfer to zero address");
		ERC1400MockToken.transferByPartition(SHARED_SPACES_PARTITION, address(0), 1000e18, "");
		vm.stopPrank();
	}

	function testTransferByPartitionShouldNotTransferZeroAmount() public {
		vm.startPrank(alice);
		vm.expectRevert("ERC1400: zero amount");
		ERC1400MockToken.transferByPartition(SHARED_SPACES_PARTITION, bob, 0, "");
		vm.stopPrank();
	}

	function testTransferByPartitionShouldNotTransferOnDefaultPartition() public {
		vm.startPrank(alice);
		vm.expectRevert("ERC1400: Wrong partition (DEFAULT_PARTITION)");
		ERC1400MockToken.transferByPartition(DEFAULT_PARTITION, bob, 1000e18, "");
		vm.stopPrank();
	}

	function testTransferByPartitionShouldNotTransferToNonERC1400ReceiverImplementerContract() public {
		vm.startPrank(alice);
		vm.expectRevert("ERC1400: transfer to non ERC1400Receiver implementer");
		ERC1400MockToken.transferByPartition(
			SHARED_SPACES_PARTITION,
			address(nonERC1400ReceivableContract),
			1000e18,
			""
		);
		vm.stopPrank();
	}

	function testTransferByPartitionShouldTransferToERC1400ReceiverImplementerContract() public {
		vm.startPrank(alice);
		vm.expectEmit(true, true, true, true);
		emit TransferByPartition(
			SHARED_SPACES_PARTITION,
			alice,
			alice,
			address(ERC1400ReceivableContract),
			1000e18,
			"",
			""
		);
		ERC1400MockToken.transferByPartition(SHARED_SPACES_PARTITION, address(ERC1400ReceivableContract), 1000e18, "");
		vm.stopPrank();
	}

	function testTransferByPartitionReturnsPartition() public {
		vm.startPrank(alice);
		vm.expectEmit(true, true, true, true);
		emit TransferByPartition(SHARED_SPACES_PARTITION, alice, alice, bob, 1000e18, "", "");
		bytes32 partition = ERC1400MockToken.transferByPartition(SHARED_SPACES_PARTITION, bob, 1000e18, "");
		vm.stopPrank();

		assertEq(partition, SHARED_SPACES_PARTITION, "Bob's shared spaces partition balance should be 1000e18");
	}

	function testShouldTransferByPartition() public {
		uint256 aliceBalancePrior = ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, alice);
		uint256 bobBalancePrior = ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, bob);

		vm.startPrank(alice);
		vm.expectEmit(true, true, true, true);
		emit TransferByPartition(SHARED_SPACES_PARTITION, alice, alice, bob, 100e18, "", "");
		ERC1400MockToken.transferByPartition(SHARED_SPACES_PARTITION, bob, 100e18, "");
		vm.stopPrank();

		uint256 aliceBalanceAfter = ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, alice);
		uint256 bobBalanceAfter = ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, bob);

		assertEq(
			aliceBalanceAfter,
			aliceBalancePrior - 100e18,
			"Alice's shared spaces partition balance should reduce by 100e18"
		);

		assertEq(
			bobBalanceAfter,
			bobBalancePrior + 100e18,
			"Bob's shared spaces partition balance should increase by 100e18"
		);
	}

	function testOperatorTransferByPartitionShouldFailWhenNotOperator() public {
		vm.startPrank(alice);
		vm.expectRevert("ERC1400: Not authorized operator");
		ERC1400MockToken.operatorTransferByPartition(SHARED_SPACES_PARTITION, alice, bob, 100e18, "", "");
		vm.stopPrank();
	}

	function testOperatorTransferByPartitionShouldFailWhenReceiverZeroAddress() public {
		vm.startPrank(alice);
		ERC1400MockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, aliceOperator);
		vm.stopPrank();

		vm.startPrank(aliceOperator);
		vm.expectRevert("ERC1400: transfer to zero address");
		ERC1400MockToken.operatorTransferByPartition(SHARED_SPACES_PARTITION, alice, address(0), 100e18, "", "");
		vm.stopPrank();
	}

	function testOperatorTransferByPartitionShouldFailWhenAmountZero() public {
		vm.startPrank(alice);
		ERC1400MockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, aliceOperator);
		vm.stopPrank();

		vm.startPrank(aliceOperator);
		vm.expectRevert("ERC1400: zero amount");
		ERC1400MockToken.operatorTransferByPartition(SHARED_SPACES_PARTITION, alice, bob, 0, "", "");
		vm.stopPrank();
	}

	function testOperatorTransferByPartitionShouldFailWhenNotUserOperator() public {
		vm.startPrank(alice);
		ERC1400MockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, bobOperator);
		vm.stopPrank();

		vm.startPrank(aliceOperator);
		vm.expectRevert("ERC1400: Not authorized operator");
		ERC1400MockToken.operatorTransferByPartition(SHARED_SPACES_PARTITION, bob, alice, 100e18, "", "");
		vm.stopPrank();
	}

	function testOperatorTransferByPartition() public {
		vm.startPrank(alice);
		ERC1400MockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, aliceOperator);
		vm.stopPrank();

		uint256 aliceBalancePrior = ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, alice);
		uint256 bobBalancePrior = ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, bob);

		vm.startPrank(aliceOperator);
		vm.expectEmit(true, true, true, true);
		emit TransferByPartition(SHARED_SPACES_PARTITION, aliceOperator, alice, bob, 100e18, "", "");
		ERC1400MockToken.operatorTransferByPartition(SHARED_SPACES_PARTITION, alice, bob, 100e18, "", "");
		vm.stopPrank();

		uint256 aliceBalanceAfter = ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, alice);
		uint256 bobBalanceAfter = ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, bob);

		assertEq(
			aliceBalanceAfter,
			aliceBalancePrior - 100e18,
			"Alice's shared spaces partition balance should reduce by 100e18"
		);

		assertEq(
			bobBalanceAfter,
			bobBalancePrior + 100e18,
			"Bob's shared spaces partition balance should increase by 100e18"
		);
	}

	function testControllerTransferShouldFailWhenNotController() public {
		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400: not a controller");
		ERC1400MockToken.controllerTransfer(tokenAdmin, bob, 1000e18, "", "");
		vm.stopPrank();
	}

	function testControllerTransferShouldFailWithInsufficientAmount() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		vm.startPrank(tokenController1);
		vm.expectRevert("ERC1400: insufficient balance");
		ERC1400MockToken.controllerTransfer(alice, bob, 1000e18, "", "");
		vm.stopPrank();
	}

	function testControllerTransferShouldFailWhenZeroAmount() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		vm.startPrank(tokenController1);
		vm.expectRevert("ERC1400: zero amount");
		ERC1400MockToken.controllerTransfer(tokenAdmin, bob, 0, "", "");
		vm.stopPrank();
	}

	function testControllerTransfer() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		uint256 tokenAdminBalancePrior = ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, tokenAdmin);
		uint256 bobBalancePrior = ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, bob);

		vm.startPrank(tokenController1);
		vm.expectEmit(true, true, true, true);
		emit ControllerTransfer(tokenController1, tokenAdmin, bob, 1000e18, "", "");
		ERC1400MockToken.controllerTransfer(tokenAdmin, bob, 1000e18, "", "");
		vm.stopPrank();

		uint256 tokenAdminBalanceAfter = ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, tokenAdmin);
		uint256 bobBalanceAfter = ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, bob);

		assertEq(
			tokenAdminBalanceAfter,
			tokenAdminBalancePrior - 1000e18,
			"TokenAdmin's shared spaces partition balance should reduce by 100e18"
		);

		assertEq(
			bobBalanceAfter,
			bobBalancePrior + 1000e18,
			"Bob's shared spaces partition balance should increase by 100e18"
		);
	}

	function testControllerTransferShouldFailWhenNotControllerByPartition() public {
		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400: not a controller");
		ERC1400MockToken.controllerTransferByPartition(SHARED_SPACES_PARTITION, alice, bob, 1000e18, "", "");
		vm.stopPrank();
	}

	function testControllerTransferShouldFailWithInsufficientAmountByPartition() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		vm.startPrank(tokenController1);
		vm.expectRevert("ERC1400: insufficient balance");
		ERC1400MockToken.controllerTransferByPartition(SHARED_SPACES_PARTITION, tokenAdmin, bob, 1000e18, "", "");
		vm.stopPrank();
	}

	function testControllerTransferShouldFailWhenZeroAmountByPartition() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		vm.startPrank(tokenController1);
		vm.expectRevert("ERC1400: zero amount");
		ERC1400MockToken.controllerTransferByPartition(SHARED_SPACES_PARTITION, alice, bob, 0, "", "");
		vm.stopPrank();
	}

	function testControllerTransferByPartitionShouldFailWhenWrongPartition() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		vm.startPrank(tokenController1);
		vm.expectRevert("ERC1400: Wrong partition (DEFAULT_PARTITION)");
		ERC1400MockToken.controllerTransferByPartition(DEFAULT_PARTITION, alice, bob, 1000e18, "", "");
		vm.stopPrank();
	}

	function testControllerTransferByPartition() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		uint256 aliceBalancePrior = ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, alice);
		uint256 bobBalancePrior = ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, bob);

		vm.startPrank(tokenController1);
		vm.expectEmit(true, true, true, true);
		emit ControllerTransferByPartition(SHARED_SPACES_PARTITION, tokenController1, alice, bob, 1000e18, "", "");
		ERC1400MockToken.controllerTransferByPartition(SHARED_SPACES_PARTITION, alice, bob, 1000e18, "", "");
		vm.stopPrank();

		uint256 aliceBalanceAfter = ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, alice);
		uint256 bobBalanceAfter = ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, bob);

		assertEq(
			aliceBalanceAfter,
			aliceBalancePrior - 1000e18,
			"Alice's shared spaces partition balance should reduce by 100e18"
		);

		assertEq(
			bobBalanceAfter,
			bobBalancePrior + 1000e18,
			"Bob's shared spaces partition balance should increase by 100e18"
		);
	}

	function testShouldNotTransferFromWithInsufficientAllowance() public {
		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400: insufficient allowance");
		ERC1400MockToken.transferFrom(tokenAdmin, bob, 1000e18);
		vm.stopPrank();
	}

	function testShouldNotTransferFromToZeroAddress() public {
		vm.startPrank(tokenAdmin);
		ERC1400MockToken.approve(bob, 1000e18);
		vm.stopPrank();

		vm.startPrank(bob);
		vm.expectRevert("ERC1400: transfer to zero address");
		ERC1400MockToken.transferFrom(tokenAdmin, address(0), 1000e18);
		vm.stopPrank();
	}

	function testShouldNotTransferFromZeroAmount() public {
		vm.startPrank(tokenAdmin);
		ERC1400MockToken.approve(bob, 1000e18);
		vm.stopPrank();

		vm.startPrank(bob);
		vm.expectRevert("ERC1400: zero amount");
		ERC1400MockToken.transferFrom(tokenAdmin, bob, 0);
		vm.stopPrank();
	}

	function testShouldNotTransferFromToNonERC1400ReceiverImplementerContract() public {
		vm.startPrank(tokenAdmin);
		ERC1400MockToken.approve(bob, 1000e18);
		vm.stopPrank();

		vm.startPrank(bob);
		vm.expectRevert("ERC1400: transfer to non ERC1400Receiver implementer");
		ERC1400MockToken.transferFrom(tokenAdmin, address(nonERC1400ReceivableContract), 1000e18);
		vm.stopPrank();
	}

	function testShouldTransferFromToERC1400ReceiverImplementerContract() public {
		vm.startPrank(tokenAdmin);
		ERC1400MockToken.approve(bob, 1000e18);
		vm.stopPrank();

		vm.startPrank(bob);
		vm.expectEmit(true, true, true, true);
		emit Transfer(tokenAdmin, address(ERC1400ReceivableContract), 1000e18);
		ERC1400MockToken.transferFrom(tokenAdmin, address(ERC1400ReceivableContract), 1000e18);
		vm.stopPrank();
	}

	function testTransferFromTokensOnDefaultPartition() public {
		uint256 tokenAdminBalancePrior = ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, tokenAdmin);

		vm.startPrank(tokenAdmin);
		ERC1400MockToken.approve(bob, 1000e18);
		vm.stopPrank();

		vm.startPrank(bob);
		vm.expectEmit(true, true, true, true);
		emit Transfer(tokenAdmin, alice, 1000e18);
		ERC1400MockToken.transferFrom(tokenAdmin, alice, 1000e18);
		vm.stopPrank();

		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, alice),
			1000e18,
			"Alice's default partition balance should be 1000e18"
		);
		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, tokenAdmin),
			tokenAdminBalancePrior - 1000e18,
			"Admin's balance should reduce by 1000e18"
		);
	}

	function testShouldNotTransferFromWithDataWhenInvalidSigner() public {
		///@notice invalid signer used
		bytes memory transferData = prepareTransferSignature(999, DEFAULT_PARTITION, tokenAdmin, alice, 100e18, 0, 0);

		vm.startPrank(tokenAdmin);
		ERC1400MockToken.approve(bob, 1000e18);
		vm.stopPrank();

		vm.startPrank(bob);
		vm.expectRevert("ERC1400: invalid data");
		ERC1400MockToken.transferFromWithData(alice, tokenAdmin, 100e18, transferData);
		vm.stopPrank();
	}
}
