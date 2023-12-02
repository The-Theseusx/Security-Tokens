//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1400 } from "../../src/ERC1400/ERC1400.sol";
import { ERC1400IssuanceTest } from "./ERC1400Issuance.t.sol";
import { ERC1400RedemptionTest } from "./ERC1400Redemption.t.sol";
import { ERC1400TransferTest } from "./ERC1400Transfer.t.sol";
import { ERC1400ApprovalTest } from "./ERC1400Approval.t.sol";
import { ERC1400CanTransferTest } from "./ERC1400CanTransfer.t.sol";
import { ERC1400DocumentTest } from "./ERC1400Document.t.sol";

contract ERC1400Test is
	ERC1400IssuanceTest,
	ERC1400RedemptionTest,
	ERC1400TransferTest,
	ERC1400ApprovalTest,
	ERC1400CanTransferTest,
	ERC1400DocumentTest
{
	function testItHasAName() public {
		string memory name = ERC1400MockToken.name();
		assertEq(name, TOKEN_NAME, "token name is not correct");
	}

	function testItHasASymbol() public {
		string memory symbol = ERC1400MockToken.symbol();
		assertEq(symbol, TOKEN_SYMBOL, "token symbol is not correct");
	}

	function testItHas18Decimals() public {
		uint8 decimals = ERC1400MockToken.decimals();
		assertEq(decimals, uint8(18), "token decimals is not correct");
	}

	function testShouldNotDisableIssuanceWhenNotAdmin() public {
		string memory errMsg = accessControlError(notTokenAdmin, ERC1400MockToken.ERC1400_ADMIN_ROLE());

		vm.startPrank(notTokenAdmin);
		vm.expectRevert(bytes(errMsg));
		ERC1400MockToken.disableIssuance();
		vm.stopPrank();
	}

	function testShouldDisableIssuanceWhenAdmin() public {
		vm.startPrank(tokenAdmin);
		ERC1400MockToken.disableIssuance();
		vm.stopPrank();

		assertFalse(ERC1400MockToken.isIssuable(), "Token should not be issuable");
	}

	function testShouldNotApproveSenderAsOperator() public {
		vm.startPrank(alice);
		vm.expectRevert("ERC1400: self authorization not allowed");
		ERC1400MockToken.authorizeOperator(alice);
		vm.stopPrank();
	}

	function testShouldApproveOperator() public {
		vm.startPrank(alice);

		vm.expectEmit(true, true, true, false);
		emit AuthorizedOperator(aliceOperator, alice);

		ERC1400MockToken.authorizeOperator(aliceOperator);
		vm.stopPrank();

		assertTrue(ERC1400MockToken.isOperator(aliceOperator, alice), "aliceOperator should be an operator");
	}

	function testShouldNotApproveSenderAsOperatorByPartition() public {
		vm.startPrank(alice);
		vm.expectRevert("ERC1400: self authorization not allowed");
		ERC1400MockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, alice);
		vm.stopPrank();
	}

	function testShouldApproveOperatorByPartition() public {
		vm.startPrank(alice);

		vm.expectEmit(true, true, true, true);
		emit AuthorizedOperatorByPartition(SHARED_SPACES_PARTITION, aliceOperator, alice);

		ERC1400MockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, aliceOperator);
		vm.stopPrank();

		assertFalse(
			ERC1400MockToken.isOperator(aliceOperator, alice),
			"aliceOperator should not be an operator but operator of shared spaces Partition"
		);
		assertFalse(
			ERC1400MockToken.isOperatorForPartition(DEFAULT_PARTITION, aliceOperator, alice),
			"aliceOperator should be an operator for the default partition"
		);
		assertTrue(
			ERC1400MockToken.isOperatorForPartition(SHARED_SPACES_PARTITION, aliceOperator, alice),
			"aliceOperator should be an operator for shared spaces partition"
		);
	}

	function testShouldApproveOperatorForDefaultPartition() public {
		vm.startPrank(bob);
		vm.expectEmit(true, true, true, true);
		emit AuthorizedOperatorByPartition(DEFAULT_PARTITION, bobOperator, bob);

		ERC1400MockToken.authorizeOperatorByPartition(DEFAULT_PARTITION, bobOperator);
		vm.stopPrank();

		assertFalse(
			ERC1400MockToken.isOperator(bobOperator, bob),
			"aliceOperator should not be an operator but operator of shared spaces Partition"
		);
		assertFalse(
			ERC1400MockToken.isOperatorForPartition(SHARED_SPACES_PARTITION, bobOperator, bob),
			"aliceOperator should be an operator for the default partition"
		);
		assertTrue(
			ERC1400MockToken.isOperatorForPartition(DEFAULT_PARTITION, bobOperator, bob),
			"aliceOperator should be an operator for shared spaces partition"
		);
	}

	function testShouldRevokeOperator() public {
		vm.startPrank(alice);
		ERC1400MockToken.authorizeOperator(aliceOperator);

		skip(1 minutes);

		vm.expectEmit(true, true, true, false);
		emit RevokedOperator(aliceOperator, alice);

		ERC1400MockToken.revokeOperator(aliceOperator);

		assertFalse(ERC1400MockToken.isOperator(aliceOperator, alice), "aliceOperator should be revoked");
		vm.stopPrank();
	}

	function testShouldRevokeAllOperatorsOfUser() public {
		vm.startPrank(bob);
		ERC1400MockToken.authorizeOperator(aliceOperator);
		ERC1400MockToken.authorizeOperator(bobOperator);
		ERC1400MockToken.authorizeOperatorByPartition(DEFAULT_PARTITION, tokenAdminOperator);
		ERC1400MockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, notTokenAdminOperator);
		vm.stopPrank();

		assertTrue(ERC1400MockToken.isOperator(aliceOperator, bob), "aliceOperator should be an operator for Bob");
		assertTrue(ERC1400MockToken.isOperator(bobOperator, bob), "bobOperator should be an operator for Bob");
		assertTrue(
			ERC1400MockToken.isOperatorForPartition(DEFAULT_PARTITION, tokenAdminOperator, bob),
			"tokenAdminOperator should be an operator of the default partition for Bob"
		);
		assertTrue(
			ERC1400MockToken.isOperatorForPartition(SHARED_SPACES_PARTITION, notTokenAdminOperator, bob),
			"notTokenAdminOperator should be an operator of shared spaces partition for Bob"
		);

		address[] memory operators = new address[](4);
		operators[0] = bobOperator;
		operators[1] = aliceOperator;
		operators[2] = tokenAdminOperator;
		operators[3] = notTokenAdminOperator;

		vm.startPrank(bob);
		ERC1400MockToken.revokeOperators(operators);
		vm.stopPrank();

		assertFalse(ERC1400MockToken.isOperator(aliceOperator, bob), "aliceOperator should not be an operator for Bob");
		assertFalse(ERC1400MockToken.isOperator(bobOperator, bob), "bobOperator should not be an operator for Bob");
		assertFalse(
			ERC1400MockToken.isOperatorForPartition(DEFAULT_PARTITION, tokenAdminOperator, bob),
			"tokenAdminOperator should not be an operator of the default partition for Bob"
		);
		assertFalse(
			ERC1400MockToken.isOperatorForPartition(SHARED_SPACES_PARTITION, notTokenAdminOperator, bob),
			"notTokenAdminOperator should not be an operator of shared spaces partition for Bob"
		);
	}

	function testShouldRevokeOperatorsForDefaultPartitionOnly() public {
		///@dev @notice notTokenAdmin has no tokens and no partitions.
		vm.startPrank(notTokenAdmin);
		ERC1400MockToken.authorizeOperatorByPartition(DEFAULT_PARTITION, tokenAdminOperator);
		ERC1400MockToken.authorizeOperatorByPartition(DEFAULT_PARTITION, notTokenAdminOperator);
		vm.stopPrank();

		assertTrue(
			ERC1400MockToken.isOperatorForPartition(DEFAULT_PARTITION, tokenAdminOperator, notTokenAdmin),
			"tokenAdminOperator should be an operator of the default partition for notTokenAdmin"
		);

		assertTrue(
			ERC1400MockToken.isOperatorForPartition(DEFAULT_PARTITION, notTokenAdminOperator, notTokenAdmin),
			"notTokenAdminOperator should be an operator of the default partition for notTokenAdmin"
		);

		address[] memory operators = new address[](2);
		operators[0] = tokenAdminOperator;
		operators[1] = notTokenAdminOperator;

		vm.startPrank(notTokenAdmin);
		ERC1400MockToken.revokeOperators(operators);
		vm.stopPrank();

		assertFalse(
			ERC1400MockToken.isOperatorForPartition(DEFAULT_PARTITION, tokenAdminOperator, notTokenAdmin),
			"tokenAdminOperator should not be an operator of the default partition for notTokenAdmin"
		);

		assertFalse(
			ERC1400MockToken.isOperatorForPartition(DEFAULT_PARTITION, notTokenAdminOperator, notTokenAdmin),
			"notTokenAdminOperator should not be an operator of the default partition for notTokenAdmin"
		);
	}

	function testShouldNotAddControllersWhenNotAdmin() public {
		string memory errMsg = accessControlError(notTokenAdmin, ERC1400MockToken.ERC1400_ADMIN_ROLE());

		address[] memory controllers = new address[](3);
		controllers[0] = tokenController1;
		controllers[1] = tokenController2;
		controllers[2] = tokenController3;

		vm.startPrank(notTokenAdmin);
		vm.expectRevert(bytes(errMsg));
		ERC1400MockToken.addControllers(controllers);
		vm.stopPrank();
	}

	function testShouldNotAddAddressZeroAsController() public {
		address[] memory controllers = new address[](3);
		controllers[0] = tokenController1;
		controllers[1] = address(0);
		controllers[2] = tokenController3;

		vm.startPrank(tokenAdmin);
		vm.expectRevert(bytes("ERC1400: controller is zero address"));
		ERC1400MockToken.addControllers(controllers);
		vm.stopPrank();
	}

	function testShouldAddControllers() public {
		address[] memory controllers = new address[](3);
		controllers[0] = tokenController1;
		controllers[1] = tokenController2;
		controllers[2] = tokenController3;

		vm.startPrank(tokenAdmin);
		for (uint256 i; i < controllers.length; ++i) {
			vm.expectEmit(true, true, false, false);
			emit ControllerAdded(controllers[i]);
		}
		ERC1400MockToken.addControllers(controllers);
		vm.stopPrank();

		assertTrue(ERC1400MockToken.isControllable(), "Token should be controllable");
		assertTrue(ERC1400MockToken.isController(controllers[0]), "controller[0] should be a controller");
		assertTrue(ERC1400MockToken.isController(controllers[1]), "controller[1] should be a controller");
		assertTrue(ERC1400MockToken.isController(controllers[2]), "controller[2] should be a controller");
	}

	function testShouldNotRemoveControllersWhenNotAdmin() public {
		string memory errMsg = accessControlError(notTokenAdmin, ERC1400MockToken.ERC1400_ADMIN_ROLE());

		address[] memory controllers = new address[](3);
		controllers[0] = tokenController1;
		controllers[1] = tokenController2;
		controllers[2] = tokenController3;

		vm.startPrank(notTokenAdmin);
		vm.expectRevert(bytes(errMsg));
		ERC1400MockToken.removeControllers(controllers);
		vm.stopPrank();
	}

	function testShouldNotRemoveControllerAddress0() public {
		vm.startPrank(tokenAdmin);
		_addControllers(); ///@dev adding controllers

		address[] memory controllers = new address[](3);
		controllers[0] = tokenController1;
		controllers[1] = address(0);
		controllers[2] = tokenController3;

		vm.expectRevert(bytes("ERC1400: controller is zero address"));
		ERC1400MockToken.removeControllers(controllers);
		vm.stopPrank();
	}

	function testShouldNotRemoveNonControllers() public {
		vm.startPrank(tokenAdmin);

		_addControllers(); ///@dev adding controllers

		address[] memory controllers = new address[](3);
		controllers[0] = tokenController1;
		controllers[1] = tokenController3;
		controllers[2] = notTokenAdmin;

		vm.expectRevert("ERC1400: not controller");
		ERC1400MockToken.removeControllers(controllers);
		vm.stopPrank();
	}

	function testShouldRemoveControllers() public {
		vm.startPrank(tokenAdmin);

		_addControllers(); ///@dev adding controllers
		address[] memory controllers = new address[](2);
		controllers[0] = tokenController2;
		controllers[1] = tokenController3;

		for (uint256 i; i < controllers.length; ++i) {
			vm.expectEmit(true, true, false, false);
			emit ControllerRemoved(controllers[i]);
		}
		ERC1400MockToken.removeControllers(controllers);
		vm.stopPrank();

		///@notice we did not remove tokenController1 as a controller at this point

		assertTrue(ERC1400MockToken.isControllable(), "Token should be controllable");
		assertTrue(ERC1400MockToken.isController(tokenController1), "tokenController1 should be a controller");
		assertFalse(ERC1400MockToken.isController(controllers[0]), "tokenController2 should not be a controller");
		assertFalse(ERC1400MockToken.isController(controllers[1]), "tokenController3 should not be a controller");

		///@dev finally remove all controllers
		address[] memory controllers_ = new address[](1);
		controllers_[0] = tokenController1;
		vm.startPrank(tokenAdmin);
		ERC1400MockToken.removeControllers(controllers_);
		vm.stopPrank();

		assertFalse(ERC1400MockToken.isControllable(), "Token should not be controllable");
		assertFalse(ERC1400MockToken.isController(tokenController1), "tokenController1 should not be a controller");
	}

	function testUserPartitionsUpdateProperly() public {
		bytes32 newPartition1 = keccak256("newPartition1");
		bytes32 newPartition2 = keccak256("newPartition2");

		vm.startPrank(tokenIssuer);
		_issueTokens(newPartition1, alice, 100e18, "");
		_issueTokens(newPartition2, alice, 100e18, "");
		_issueTokens(newPartition1, bob, 200e18, "");
		vm.stopPrank();

		///@dev alice should have 3 partitions (shared spaces, newPartition1, newPartition2)

		bytes32[] memory alicePartitions = ERC1400MockToken.partitionsOf(alice);
		assertEq(alicePartitions.length, 3, "alice should have 3 partitions");
		assertEq(alicePartitions[0], SHARED_SPACES_PARTITION, "alice should have shared spaces partition");
		assertEq(alicePartitions[1], newPartition1, "alice should have newPartition1");
		assertEq(alicePartitions[2], newPartition2, "alice should have newPartition2");

		assertTrue(
			ERC1400MockToken.isUserPartition(SHARED_SPACES_PARTITION, alice),
			"alice should have shared spaces partition"
		);
		assertTrue(ERC1400MockToken.isUserPartition(newPartition1, alice), "alice should have newPartition1 partition");
		assertTrue(ERC1400MockToken.isUserPartition(newPartition2, alice), "alice should have newPartition2 partition");

		///@dev bob should have 2 partitions (SHARED_SPACES_PARTITION, newPartition1)

		bytes32[] memory bobPartitions = ERC1400MockToken.partitionsOf(bob);
		assertEq(bobPartitions.length, 2, "bob should have 2 partitions");
		assertEq(bobPartitions[0], SHARED_SPACES_PARTITION, "bob should have default partition");
		assertEq(bobPartitions[1], newPartition1, "bob should have newPartition1");

		assertTrue(
			ERC1400MockToken.isUserPartition(SHARED_SPACES_PARTITION, bob),
			"bob should have shared spaces partition"
		);
		assertTrue(ERC1400MockToken.isUserPartition(newPartition1, bob), "bob should have newPartition1 partition");
		assertFalse(
			ERC1400MockToken.isUserPartition(newPartition2, bob),
			"bob should not have newPartition2 partition"
		);
	}
}
