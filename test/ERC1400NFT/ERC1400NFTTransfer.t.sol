//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console2 } from "forge-std/Test.sol";
import { ERC1400NFTBaseTest } from "./ERC1400NFTBaseTest.t.sol";

abstract contract ERC1400NFTTransferTest is ERC1400NFTBaseTest {
	function testTransferFromCanTransferForCaller() public {
		uint256 adminBalancePrior = ERC1400NFTMockToken.balanceOf(tokenAdmin);
		uint256 aliceBalancePrior = ERC1400NFTMockToken.balanceOf(alice);
		vm.startPrank(tokenAdmin);
		vm.expectEmit(true, true, true, true);
		emit Transfer(tokenAdmin, tokenAdmin, alice, ADMIN_INITIAL_TOKEN_ID, DEFAULT_PARTITION, "", "");
		ERC1400NFTMockToken.transferFrom(tokenAdmin, alice, ADMIN_INITIAL_TOKEN_ID);
		vm.stopPrank();

		assertEq(
			ERC1400NFTMockToken.balanceOf(tokenAdmin),
			adminBalancePrior - 1,
			"tokenAdmin balance should be decreased by 1"
		);
		assertEq(ERC1400NFTMockToken.balanceOf(alice), aliceBalancePrior + 1, "alice balance should be increased by 1");
		assertEq(
			ERC1400NFTMockToken.ownerOf(ADMIN_INITIAL_TOKEN_ID),
			alice,
			"alice should be the owner of ADMIN_INITIAL_TOKEN_ID"
		);
	}

	function testTransferFromShouldFailIfCallerNotTokenOwner() public {
		vm.startPrank(alice);
		vm.expectRevert("ERC1400NFT: not owner or approved");
		ERC1400NFTMockToken.transferFrom(alice, bob, ADMIN_INITIAL_TOKEN_ID);
		vm.stopPrank();
	}

	function testTransferFromShouldFailIfTokenNotIssued() public {
		///@dev notice this call would fail for various reasons if the token was not issued
		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400NFT: non-existent token");
		ERC1400NFTMockToken.transferFrom(tokenAdmin, alice, 999);
		vm.stopPrank();
	}

	function testTransferFromShouldFailIfCallerNotApprovedByOwner() public {
		vm.startPrank(alice);
		vm.expectRevert("ERC1400NFT: not owner or approved");
		ERC1400NFTMockToken.transferFrom(alice, bob, ADMIN_INITIAL_TOKEN_ID);
		vm.stopPrank();
	}

	function testTransferFrom() public {
		uint256 adminBalancePrior = ERC1400NFTMockToken.balanceOf(tokenAdmin);
		uint256 aliceBalancePrior = ERC1400NFTMockToken.balanceOf(alice);

		vm.startPrank(tokenAdmin);
		ERC1400NFTMockToken.approve(alice, ADMIN_INITIAL_TOKEN_ID);
		vm.stopPrank();

		vm.startPrank(alice);
		vm.expectEmit(true, true, true, true);
		emit Transfer(alice, tokenAdmin, alice, ADMIN_INITIAL_TOKEN_ID, DEFAULT_PARTITION, "", "");
		ERC1400NFTMockToken.transferFrom(tokenAdmin, alice, ADMIN_INITIAL_TOKEN_ID);
		vm.stopPrank();

		assertEq(
			ERC1400NFTMockToken.balanceOf(tokenAdmin),
			adminBalancePrior - 1,
			"tokenAdmin balance should be decreased by 1"
		);
		assertEq(ERC1400NFTMockToken.balanceOf(alice), aliceBalancePrior + 1, "alice balance should be increased by 1");
		assertEq(
			ERC1400NFTMockToken.ownerOf(ADMIN_INITIAL_TOKEN_ID),
			alice,
			"alice should be the owner of ADMIN_INITIAL_TOKEN_ID"
		);
	}

	function testTransferWithData() public {
		uint256 adminBalancePrior = ERC1400NFTMockToken.balanceOf(tokenAdmin);
		uint256 aliceBalancePrior = ERC1400NFTMockToken.balanceOf(alice);

		vm.startPrank(tokenAdmin);
		vm.expectEmit(true, true, true, true);
		emit Transfer(tokenAdmin, tokenAdmin, alice, ADMIN_INITIAL_TOKEN_ID, DEFAULT_PARTITION, "example data", "");
		ERC1400NFTMockToken.transferWithData(alice, ADMIN_INITIAL_TOKEN_ID, "example data");
		vm.stopPrank();

		assertEq(
			ERC1400NFTMockToken.balanceOf(tokenAdmin),
			adminBalancePrior - 1,
			"tokenAdmin balance should be decreased by 1"
		);

		assertEq(ERC1400NFTMockToken.balanceOf(alice), aliceBalancePrior + 1, "alice balance should be increased by 1");

		assertEq(
			ERC1400NFTMockToken.ownerOf(ADMIN_INITIAL_TOKEN_ID),
			alice,
			"alice should be the owner of ADMIN_INITIAL_TOKEN_ID"
		);
	}

	function testTransferFromWithDataShouldFailIfInvalidSigner() public {
		bytes memory transferData = prepareTransferSignature(
			NOT_ADMIN_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			alice,
			ADMIN_INITIAL_TOKEN_ID,
			0,
			0
		);

		vm.startPrank(alice);
		vm.expectRevert("ERC1400NFT: Invalid data");
		ERC1400NFTMockToken.transferFromWithData(tokenAdmin, alice, ADMIN_INITIAL_TOKEN_ID, transferData);
		vm.stopPrank();
	}

	function testTransferFromWithDataShouldFailIfInvalidTokenOwner() public {
		bytes memory transferData = prepareTransferSignature(
			TOKEN_TRANSFER_AGENT_PK,
			DEFAULT_PARTITION,
			alice,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			0,
			0
		);
		///@notice Alice is not the owner of ADMIN_INITIAL_TOKEN_ID
		vm.startPrank(alice);
		vm.expectRevert("ERC1400NFT: not token owner");
		ERC1400NFTMockToken.transferFromWithData(alice, tokenAdmin, ADMIN_INITIAL_TOKEN_ID, transferData);
		vm.stopPrank();
	}

	function testTransferFromWithDataShouldFailIfNotExistentToken() public {
		bytes memory transferData = prepareTransferSignature(
			TOKEN_TRANSFER_AGENT_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			alice,
			999,
			0,
			0
		);
		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400NFT: non-existent token");
		ERC1400NFTMockToken.transferFromWithData(tokenAdmin, alice, 999, transferData);
		vm.stopPrank();
	}

	function testTransferFromWithData() public {
		bytes memory transferData = prepareTransferSignature(
			TOKEN_TRANSFER_AGENT_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			alice,
			ADMIN_INITIAL_TOKEN_ID,
			0,
			0
		);

		uint256 adminBalancePrior = ERC1400NFTMockToken.balanceOf(tokenAdmin);
		uint256 aliceBalancePrior = ERC1400NFTMockToken.balanceOf(alice);

		vm.startPrank(alice);
		vm.expectEmit(true, true, true, true);
		emit Transfer(alice, tokenAdmin, alice, ADMIN_INITIAL_TOKEN_ID, DEFAULT_PARTITION, transferData, "");
		ERC1400NFTMockToken.transferFromWithData(tokenAdmin, alice, ADMIN_INITIAL_TOKEN_ID, transferData);
		vm.stopPrank();

		assertEq(
			ERC1400NFTMockToken.balanceOf(tokenAdmin),
			adminBalancePrior - 1,
			"tokenAdmin balance should be decreased by 1"
		);

		assertEq(ERC1400NFTMockToken.balanceOf(alice), aliceBalancePrior + 1, "alice balance should be increased by 1");

		assertEq(
			ERC1400NFTMockToken.ownerOf(ADMIN_INITIAL_TOKEN_ID),
			alice,
			"alice should be the owner of ADMIN_INITIAL_TOKEN_ID"
		);
	}

	function testTransferFromByPartitionWithoutDataShouldFailIfCallerNotTokenOwner() public {
		vm.startPrank(bob);
		vm.expectRevert("ERC1400NFT: !owner or approved");
		ERC1400NFTMockToken.transferFromByPartition(SHARED_SPACES_PARTITION, alice, bob, ALICE_INITIAL_TOKEN_ID, "");
		vm.stopPrank();
	}

	function testTransferFromByPartitionWithoutDataShouldFailIfWrongPartition() public {
		vm.startPrank(alice);
		vm.expectRevert("ERC1400NFT: !partition");
		ERC1400NFTMockToken.transferFromByPartition(DEFAULT_PARTITION, alice, bob, ALICE_INITIAL_TOKEN_ID, "");
		vm.stopPrank();
	}

	function testTransferFromByPartitionWithoutDataWithCallerAsOwner() public {
		///@notice caller must be token owner

		uint256 aliceBalancePrior = ERC1400NFTMockToken.balanceOf(alice);
		uint256 aliceSharedSpacePartitionBalancePrior = ERC1400NFTMockToken.balanceOfByPartition(
			SHARED_SPACES_PARTITION,
			alice
		);
		uint256 bobBalancePrior = ERC1400NFTMockToken.balanceOf(bob);
		uint256 bobSharedSpacePartitionBalancePrior = ERC1400NFTMockToken.balanceOfByPartition(
			SHARED_SPACES_PARTITION,
			bob
		);

		vm.startPrank(alice);
		vm.expectEmit(true, true, true, true);
		emit TransferByPartition(SHARED_SPACES_PARTITION, alice, alice, bob, ALICE_INITIAL_TOKEN_ID, "", "");
		ERC1400NFTMockToken.transferFromByPartition(SHARED_SPACES_PARTITION, alice, bob, ALICE_INITIAL_TOKEN_ID, "");
		vm.stopPrank();

		assertEq(ERC1400NFTMockToken.balanceOf(alice), aliceBalancePrior - 1, "alice balance should be decreased by 1");
		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, alice),
			aliceSharedSpacePartitionBalancePrior - 1,
			"alice balance in SHARED_SPACES_PARTITION should be decreased by 1"
		);
		assertEq(ERC1400NFTMockToken.balanceOf(bob), bobBalancePrior + 1, "bob balance should be increased by 1");
		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, bob),
			bobSharedSpacePartitionBalancePrior + 1,
			"bob balance in SHARED_SPACES_PARTITION should be increased by 1"
		);

		assertEq(
			ERC1400NFTMockToken.ownerOf(ALICE_INITIAL_TOKEN_ID),
			bob,
			"bob should be the owner of ALICE_INITIAL_TOKEN_ID"
		);
	}

	function testTransferFromWithOutDataButApproved() public {
		uint256 aliceBalancePrior = ERC1400NFTMockToken.balanceOf(alice);
		uint256 aliceSharedSpacePartitionBalancePrior = ERC1400NFTMockToken.balanceOfByPartition(
			SHARED_SPACES_PARTITION,
			alice
		);
		uint256 bobBalancePrior = ERC1400NFTMockToken.balanceOf(bob);
		uint256 bobSharedSpacePartitionBalancePrior = ERC1400NFTMockToken.balanceOfByPartition(
			SHARED_SPACES_PARTITION,
			bob
		);

		vm.startPrank(alice);
		ERC1400NFTMockToken.approveByPartition(SHARED_SPACES_PARTITION, bob, ALICE_INITIAL_TOKEN_ID);
		vm.stopPrank();

		vm.startPrank(bob);
		vm.expectEmit(true, true, true, true);
		emit TransferByPartition(SHARED_SPACES_PARTITION, bob, alice, bob, ALICE_INITIAL_TOKEN_ID, "", "");
		ERC1400NFTMockToken.transferFromByPartition(SHARED_SPACES_PARTITION, alice, bob, ALICE_INITIAL_TOKEN_ID, "");
		vm.stopPrank();

		assertEq(ERC1400NFTMockToken.balanceOf(alice), aliceBalancePrior - 1, "alice balance should be decreased by 1");
		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, alice),
			aliceSharedSpacePartitionBalancePrior - 1,
			"alice balance in SHARED_SPACES_PARTITION should be decreased by 1"
		);
		assertEq(ERC1400NFTMockToken.balanceOf(bob), bobBalancePrior + 1, "bob balance should be increased by 1");
		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, bob),
			bobSharedSpacePartitionBalancePrior + 1,
			"bob balance in SHARED_SPACES_PARTITION should be increased by 1"
		);

		assertEq(
			ERC1400NFTMockToken.ownerOf(ALICE_INITIAL_TOKEN_ID),
			bob,
			"bob should be the owner of ALICE_INITIAL_TOKEN_ID"
		);
	}

	function testTransferFromByPartitionWithDataShouldFailIfInvalidAuthorizer() public {
		bytes memory transferData = prepareTransferSignature(
			NOT_ADMIN_PK,
			SHARED_SPACES_PARTITION,
			alice,
			bob,
			ALICE_INITIAL_TOKEN_ID,
			0,
			0
		);

		vm.startPrank(bob);
		vm.expectRevert("ERC1400NFT: Invalid data");
		ERC1400NFTMockToken.transferFromByPartition(
			SHARED_SPACES_PARTITION,
			alice,
			bob,
			ALICE_INITIAL_TOKEN_ID,
			transferData
		);
		vm.stopPrank();
	}

	function testTransferFromByPartitionWithDataShouldFailIfNonExistentTokenId() public {
		bytes memory transferData = prepareTransferSignature(
			TOKEN_TRANSFER_AGENT_PK,
			SHARED_SPACES_PARTITION,
			alice,
			bob,
			999,
			0,
			0
		);

		vm.startPrank(bob);
		vm.expectRevert("ERC1400NFT: non-existent token");
		ERC1400NFTMockToken.transferFromByPartition(SHARED_SPACES_PARTITION, alice, bob, 999, transferData);
		vm.stopPrank();
	}

	function testTransferFromByPartitionWithDataShouldFailIfInvalidTokenPartition() public {
		bytes memory transferData = prepareTransferSignature(
			TOKEN_TRANSFER_AGENT_PK,
			DEFAULT_PARTITION,
			alice,
			bob,
			ALICE_INITIAL_TOKEN_ID,
			0,
			0
		);

		vm.startPrank(bob);
		vm.expectRevert("ERC1400NFT: !partition");
		ERC1400NFTMockToken.transferFromByPartition(
			DEFAULT_PARTITION,
			alice,
			bob,
			ALICE_INITIAL_TOKEN_ID,
			transferData
		);
		vm.stopPrank();
	}

	function testTransferFromByPartitionShouldFailIfInvalidPartition() public {
		bytes memory transferData = prepareTransferSignature(
			TOKEN_TRANSFER_AGENT_PK,
			bytes32("nil"),
			alice,
			bob,
			ALICE_INITIAL_TOKEN_ID,
			0,
			0
		);

		vm.startPrank(bob);
		vm.expectRevert("ERC1400NFT: nonexistent partition");
		ERC1400NFTMockToken.transferFromByPartition(bytes32("nil"), alice, bob, ALICE_INITIAL_TOKEN_ID, transferData);
		vm.stopPrank();
	}

	function testTransferFromByPartitionWithData() public {
		///@notice caller must be token owner

		uint256 aliceBalancePrior = ERC1400NFTMockToken.balanceOf(alice);
		uint256 aliceSharedSpacePartitionBalancePrior = ERC1400NFTMockToken.balanceOfByPartition(
			SHARED_SPACES_PARTITION,
			alice
		);
		uint256 bobBalancePrior = ERC1400NFTMockToken.balanceOf(bob);
		uint256 bobSharedSpacePartitionBalancePrior = ERC1400NFTMockToken.balanceOfByPartition(
			SHARED_SPACES_PARTITION,
			bob
		);

		bytes memory transferData = prepareTransferSignature(
			TOKEN_TRANSFER_AGENT_PK,
			SHARED_SPACES_PARTITION,
			alice,
			bob,
			ALICE_INITIAL_TOKEN_ID,
			0,
			0
		);

		vm.startPrank(bob);
		vm.expectEmit(true, true, true, true);
		emit TransferByPartition(SHARED_SPACES_PARTITION, bob, alice, bob, ALICE_INITIAL_TOKEN_ID, transferData, "");
		ERC1400NFTMockToken.transferFromByPartition(
			SHARED_SPACES_PARTITION,
			alice,
			bob,
			ALICE_INITIAL_TOKEN_ID,
			transferData
		);
		vm.stopPrank();

		assertEq(ERC1400NFTMockToken.balanceOf(alice), aliceBalancePrior - 1, "alice balance should be decreased by 1");
		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, alice),
			aliceSharedSpacePartitionBalancePrior - 1,
			"alice balance in SHARED_SPACES_PARTITION should be decreased by 1"
		);
		assertEq(ERC1400NFTMockToken.balanceOf(bob), bobBalancePrior + 1, "bob balance should be increased by 1");
		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, bob),
			bobSharedSpacePartitionBalancePrior + 1,
			"bob balance in SHARED_SPACES_PARTITION should be increased by 1"
		);

		assertEq(
			ERC1400NFTMockToken.ownerOf(ALICE_INITIAL_TOKEN_ID),
			bob,
			"bob should be the owner of ALICE_INITIAL_TOKEN_ID after transfer"
		);
	}

	function testOperatorTransferByPartitionShouldFailIfOperatorNotAuthorized() public {
		///@notice alice operator has not approved by Alice yet
		vm.startPrank(aliceOperator);
		vm.expectRevert("ERC1400NFT: unauthorized");
		ERC1400NFTMockToken.operatorTransferByPartition(
			SHARED_SPACES_PARTITION,
			alice,
			bob,
			ALICE_INITIAL_TOKEN_ID,
			"",
			""
		);
		vm.stopPrank();
	}

	function testOperatorTransferByPartitionShouldFailIfUserNotTokenOwner() public {
		vm.startPrank(alice);
		ERC1400NFTMockToken.authorizeOperatorByPartition(DEFAULT_PARTITION, aliceOperator);
		vm.stopPrank();

		vm.startPrank(aliceOperator);
		///@notice alice is not the owner of ADMIN_INITIAL_TOKEN_ID
		vm.expectRevert("ERC1400NFT: not token owner");
		ERC1400NFTMockToken.operatorTransferByPartition(DEFAULT_PARTITION, alice, bob, ADMIN_INITIAL_TOKEN_ID, "", "");
		vm.stopPrank();
	}

	function testOperatorTransferByPartitionShouldFailIfNonExistentToken() public {
		vm.startPrank(alice);
		ERC1400NFTMockToken.authorizeOperatorByPartition(DEFAULT_PARTITION, aliceOperator);
		vm.stopPrank();

		vm.startPrank(aliceOperator);
		vm.expectRevert("ERC1400NFT: non-existent token");
		ERC1400NFTMockToken.operatorTransferByPartition(DEFAULT_PARTITION, alice, bob, 999, "", "");
		vm.stopPrank();
	}

	function testOperatorTransferByPartition() public {
		///@notice caller must be token owner

		uint256 aliceBalancePrior = ERC1400NFTMockToken.balanceOf(alice);
		uint256 aliceSharedSpacePartitionBalancePrior = ERC1400NFTMockToken.balanceOfByPartition(
			SHARED_SPACES_PARTITION,
			alice
		);
		uint256 bobBalancePrior = ERC1400NFTMockToken.balanceOf(bob);
		uint256 bobSharedSpacePartitionBalancePrior = ERC1400NFTMockToken.balanceOfByPartition(
			SHARED_SPACES_PARTITION,
			bob
		);
		vm.startPrank(alice);
		ERC1400NFTMockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, aliceOperator);
		vm.stopPrank();

		vm.startPrank(aliceOperator);
		vm.expectEmit(true, true, true, true);
		emit TransferByPartition(SHARED_SPACES_PARTITION, aliceOperator, alice, bob, ALICE_INITIAL_TOKEN_ID, "", "");
		ERC1400NFTMockToken.operatorTransferByPartition(
			SHARED_SPACES_PARTITION,
			alice,
			bob,
			ALICE_INITIAL_TOKEN_ID,
			"",
			""
		);
		vm.stopPrank();

		assertEq(ERC1400NFTMockToken.balanceOf(alice), aliceBalancePrior - 1, "alice balance should be decreased by 1");
		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, alice),
			aliceSharedSpacePartitionBalancePrior - 1,
			"alice balance in SHARED_SPACES_PARTITION should be decreased by 1"
		);
		assertEq(ERC1400NFTMockToken.balanceOf(bob), bobBalancePrior + 1, "bob balance should be increased by 1");
		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, bob),
			bobSharedSpacePartitionBalancePrior + 1,
			"bob balance in SHARED_SPACES_PARTITION should be increased by 1"
		);

		assertEq(
			ERC1400NFTMockToken.ownerOf(ALICE_INITIAL_TOKEN_ID),
			bob,
			"bob should be the owner of ALICE_INITIAL_TOKEN_ID after transfer"
		);

		vm.startPrank(tokenAdmin);
		ERC1400NFTMockToken.authorizeOperator(tokenAdminOperator);
		vm.stopPrank();

		vm.startPrank(tokenAdminOperator);
		vm.expectEmit(true, true, true, true);
		emit Transfer(tokenAdminOperator, tokenAdmin, alice, ADMIN_INITIAL_TOKEN_ID, DEFAULT_PARTITION, "", "");
		ERC1400NFTMockToken.operatorTransferByPartition(
			DEFAULT_PARTITION,
			tokenAdmin,
			alice,
			ADMIN_INITIAL_TOKEN_ID,
			"",
			""
		);
		vm.stopPrank();

		assertEq(
			ERC1400NFTMockToken.ownerOf(ADMIN_INITIAL_TOKEN_ID),
			alice,
			"alice should be the owner of ADMIN_INITIAL_TOKEN_ID after transfer"
		);

		///@notice alice now has the admin token but has not approved her operator to spend from default partition

		vm.startPrank(aliceOperator);
		vm.expectRevert("ERC1400NFT: unauthorized");
		ERC1400NFTMockToken.operatorTransferByPartition(DEFAULT_PARTITION, alice, bob, ADMIN_INITIAL_TOKEN_ID, "", "");
		vm.stopPrank();
	}

	function testControllerTransferShouldFailIfCallerNotController() public {
		vm.startPrank(alice);
		vm.expectRevert("ERC1400NFT: not a controller");
		ERC1400NFTMockToken.controllerTransfer(alice, bob, ADMIN_INITIAL_TOKEN_ID, "", "");
		vm.stopPrank();
	}

	function testControllerTransferShouldFailIfInvalidTokenPartition() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		vm.startPrank(tokenController3);
		vm.expectRevert("ERC1400NFT: !partition");
		ERC1400NFTMockToken.controllerTransfer(tokenAdmin, bob, ALICE_INITIAL_TOKEN_ID, "", "");
		vm.stopPrank();
	}

	function testControllerTransferShouldFailIfNonExistentToken() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		vm.startPrank(tokenController1);
		vm.expectRevert("ERC1400NFT: non-existent token");
		ERC1400NFTMockToken.controllerTransfer(tokenAdmin, bob, 999, "", "");
		vm.stopPrank();
	}

	function testControllerTransfer() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		uint256 tokenAdminBalancePrior = ERC1400NFTMockToken.balanceOf(tokenAdmin);
		uint256 bobBalancePrior = ERC1400NFTMockToken.balanceOf(bob);

		vm.startPrank(tokenController1);
		vm.expectEmit(true, true, true, true);
		emit ControllerTransfer(tokenController1, tokenAdmin, bob, ADMIN_INITIAL_TOKEN_ID, "", "");
		ERC1400NFTMockToken.controllerTransfer(tokenAdmin, bob, ADMIN_INITIAL_TOKEN_ID, "", "");
		vm.stopPrank();

		assertEq(
			ERC1400NFTMockToken.balanceOf(tokenAdmin),
			tokenAdminBalancePrior - 1,
			"tokenAdmin balance should be decreased by 1"
		);
		assertEq(ERC1400NFTMockToken.balanceOf(bob), bobBalancePrior + 1, "bob balance should be increased by 1");
	}

	function testControllerTransferByPartitionShouldFailIfCallerNotController() public {
		vm.startPrank(alice);
		vm.expectRevert("ERC1400NFT: not a controller");
		ERC1400NFTMockToken.controllerTransferByPartition(
			SHARED_SPACES_PARTITION,
			alice,
			bob,
			ALICE_INITIAL_TOKEN_ID,
			"",
			""
		);
		vm.stopPrank();
	}

	function testControllerTransferByPartitionShouldFailIfInvalidTokenPartition() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		vm.startPrank(tokenController3);
		vm.expectRevert("ERC1400NFT: !partition");
		ERC1400NFTMockToken.controllerTransferByPartition(
			DEFAULT_PARTITION,
			tokenAdmin,
			bob,
			ALICE_INITIAL_TOKEN_ID,
			"",
			""
		);
		vm.stopPrank();
	}

	function testControllerTransferByPartitionShouldFailIfNonExistentToken() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		vm.startPrank(tokenController1);
		vm.expectRevert("ERC1400NFT: non-existent token");
		ERC1400NFTMockToken.controllerTransferByPartition(SHARED_SPACES_PARTITION, tokenAdmin, bob, 999, "", "");
		vm.stopPrank();
	}

	function testControllerTransferByPartitionShouldFailIfNonExistentTokenPartition() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		vm.startPrank(tokenController1);
		vm.expectRevert("ERC1400NFT: nonexistent partition");
		ERC1400NFTMockToken.controllerTransferByPartition(
			bytes32("nil"),
			tokenAdmin,
			bob,
			ALICE_INITIAL_TOKEN_ID,
			"",
			""
		);
		vm.stopPrank();
	}

	function testControllerTransferByPartition() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		uint256 aliceBalancePrior = ERC1400NFTMockToken.balanceOf(alice);
		uint256 tokenAdminBalancePrior = ERC1400NFTMockToken.balanceOf(tokenAdmin);

		vm.startPrank(tokenController1);
		vm.expectEmit(true, true, true, true);
		emit ControllerTransferByPartition(
			SHARED_SPACES_PARTITION,
			tokenController1,
			alice,
			tokenAdmin,
			ALICE_INITIAL_TOKEN_ID,
			"",
			""
		);
		ERC1400NFTMockToken.controllerTransferByPartition(
			SHARED_SPACES_PARTITION,
			alice,
			tokenAdmin,
			ALICE_INITIAL_TOKEN_ID,
			"",
			""
		);
		vm.stopPrank();

		assertEq(
			ERC1400NFTMockToken.balanceOf(tokenAdmin),
			tokenAdminBalancePrior + 1,
			"tokenAdmin balance should be increase by 1"
		);
		assertEq(ERC1400NFTMockToken.balanceOf(alice), aliceBalancePrior - 1, "bob balance should be decreased by 1");
	}
}
