//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1400NFTBaseTest } from "./ERC1400NFTBaseTest.t.sol";

contract ERC1400NFTTest is ERC1400NFTBaseTest {
	function testItHasAName() public {
		string memory name = ERC1400NFTMockToken.name();
		assertEq(name, TOKEN_NAME, "token name is not correct");
	}

	function testItHasASymbol() public {
		string memory symbol = ERC1400NFTMockToken.symbol();
		assertEq(symbol, TOKEN_SYMBOL, "token symbol is not correct");
	}

	function testShouldNotDisableIssuanceWhenNotAdmin() public {
		string memory errMsg = accessControlError(notTokenAdmin, ERC1400NFTMockToken.ERC1400_NFT_ADMIN_ROLE());

		vm.startPrank(notTokenAdmin);
		vm.expectRevert(bytes(errMsg));
		ERC1400NFTMockToken.disableIssuance();
		vm.stopPrank();
	}

	function testShouldDisableIssuanceWhenAdmin() public {
		vm.startPrank(tokenAdmin);
		ERC1400NFTMockToken.disableIssuance();
		vm.stopPrank();

		assertFalse(ERC1400NFTMockToken.isIssuable(), "Token should not be issuable");
	}

	function testShouldNotApproveSenderAsOperator() public {
		vm.startPrank(alice);
		vm.expectRevert("ERC1400NFT: self authorization not allowed");
		ERC1400NFTMockToken.authorizeOperator(alice);
		vm.stopPrank();
	}

	function testShouldApproveOperator() public {
		vm.startPrank(alice);

		vm.expectEmit(true, true, true, false);
		emit AuthorizedOperator(aliceOperator, alice);

		ERC1400NFTMockToken.authorizeOperator(aliceOperator);
		vm.stopPrank();

		assertTrue(ERC1400NFTMockToken.isOperator(aliceOperator, alice), "aliceOperator should be an operator");
	}

	function testShouldNotApproveSenderAsOperatorByPartition() public {
		vm.startPrank(alice);
		vm.expectRevert("ERC1400NFT: self authorization not allowed");
		ERC1400NFTMockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, alice);
		vm.stopPrank();
	}

	function testShouldApproveOperatorByPartition() public {
		vm.startPrank(alice);

		vm.expectEmit(true, true, true, true);
		emit AuthorizedOperatorByPartition(SHARED_SPACES_PARTITION, aliceOperator, alice);

		ERC1400NFTMockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, aliceOperator);
		vm.stopPrank();

		assertFalse(
			ERC1400NFTMockToken.isOperator(aliceOperator, alice),
			"aliceOperator should not be an operator but operator of shared spaces Partition"
		);
		assertFalse(
			ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, aliceOperator, alice),
			"aliceOperator should be an operator for the default partition"
		);
		assertTrue(
			ERC1400NFTMockToken.isOperatorForPartition(SHARED_SPACES_PARTITION, aliceOperator, alice),
			"aliceOperator should be an operator for shared spaces partition"
		);
	}

	function testShouldApproveOperatorForDefaultPartition() public {
		vm.startPrank(bob);
		vm.expectEmit(true, true, true, true);
		emit AuthorizedOperatorByPartition(DEFAULT_PARTITION, bobOperator, bob);

		ERC1400NFTMockToken.authorizeOperatorByPartition(DEFAULT_PARTITION, bobOperator);
		vm.stopPrank();

		assertFalse(
			ERC1400NFTMockToken.isOperator(bobOperator, bob),
			"aliceOperator should not be an operator but operator of shared spaces Partition"
		);
		assertFalse(
			ERC1400NFTMockToken.isOperatorForPartition(SHARED_SPACES_PARTITION, bobOperator, bob),
			"aliceOperator should be an operator for the default partition"
		);
		assertTrue(
			ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, bobOperator, bob),
			"aliceOperator should be an operator for shared spaces partition"
		);
	}

	function testShouldRevokeOperator() public {
		vm.startPrank(alice);
		ERC1400NFTMockToken.authorizeOperator(aliceOperator);

		skip(1 minutes);

		vm.expectEmit(true, true, true, false);
		emit RevokedOperator(aliceOperator, alice);

		ERC1400NFTMockToken.revokeOperator(aliceOperator);

		assertFalse(ERC1400NFTMockToken.isOperator(aliceOperator, alice), "aliceOperator should be revoked");
		vm.stopPrank();
	}

	function testShouldRevokeAllOperatorsOfUser() public {
		vm.startPrank(bob);
		ERC1400NFTMockToken.authorizeOperator(aliceOperator);
		ERC1400NFTMockToken.authorizeOperator(bobOperator);
		ERC1400NFTMockToken.authorizeOperatorByPartition(DEFAULT_PARTITION, tokenAdminOperator);
		ERC1400NFTMockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, notTokenAdminOperator);
		vm.stopPrank();

		assertTrue(ERC1400NFTMockToken.isOperator(aliceOperator, bob), "aliceOperator should be an operator for Bob");
		assertTrue(ERC1400NFTMockToken.isOperator(bobOperator, bob), "bobOperator should be an operator for Bob");
		assertTrue(
			ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, tokenAdminOperator, bob),
			"tokenAdminOperator should be an operator of the default partition for Bob"
		);
		assertTrue(
			ERC1400NFTMockToken.isOperatorForPartition(SHARED_SPACES_PARTITION, notTokenAdminOperator, bob),
			"notTokenAdminOperator should be an operator of shared spaces partition for Bob"
		);

		address[] memory operators = new address[](4);
		operators[0] = bobOperator;
		operators[1] = aliceOperator;
		operators[2] = tokenAdminOperator;
		operators[3] = notTokenAdminOperator;

		vm.startPrank(bob);
		ERC1400NFTMockToken.revokeOperators(operators);
		vm.stopPrank();

		assertFalse(
			ERC1400NFTMockToken.isOperator(aliceOperator, bob),
			"aliceOperator should not be an operator for Bob"
		);
		assertFalse(ERC1400NFTMockToken.isOperator(bobOperator, bob), "bobOperator should not be an operator for Bob");
		assertFalse(
			ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, tokenAdminOperator, bob),
			"tokenAdminOperator should not be an operator of the default partition for Bob"
		);
		assertFalse(
			ERC1400NFTMockToken.isOperatorForPartition(SHARED_SPACES_PARTITION, notTokenAdminOperator, bob),
			"notTokenAdminOperator should not be an operator of shared spaces partition for Bob"
		);
	}

	function testShouldRevokeOperatorsForDefaultPartitionOnly() public {
		///@dev @notice notTokenAdmin has no tokens and no partitions.
		vm.startPrank(notTokenAdmin);
		ERC1400NFTMockToken.authorizeOperatorByPartition(DEFAULT_PARTITION, tokenAdminOperator);
		ERC1400NFTMockToken.authorizeOperatorByPartition(DEFAULT_PARTITION, notTokenAdminOperator);
		vm.stopPrank();

		assertTrue(
			ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, tokenAdminOperator, notTokenAdmin),
			"tokenAdminOperator should be an operator of the default partition for notTokenAdmin"
		);

		assertTrue(
			ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, notTokenAdminOperator, notTokenAdmin),
			"notTokenAdminOperator should be an operator of the default partition for notTokenAdmin"
		);

		address[] memory operators = new address[](2);
		operators[0] = tokenAdminOperator;
		operators[1] = notTokenAdminOperator;

		vm.startPrank(notTokenAdmin);
		ERC1400NFTMockToken.revokeOperators(operators);
		vm.stopPrank();

		assertFalse(
			ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, tokenAdminOperator, notTokenAdmin),
			"tokenAdminOperator should not be an operator of the default partition for notTokenAdmin"
		);

		assertFalse(
			ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, notTokenAdminOperator, notTokenAdmin),
			"notTokenAdminOperator should not be an operator of the default partition for notTokenAdmin"
		);
	}
}
