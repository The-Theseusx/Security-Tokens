//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1400 } from "../../src/ERC1400/ERC1400.sol";
import { ERC1400IssuanceTest } from "./ERC1400Issuance.t.sol";
import { ERC1400RedemptionTest } from "./ERC1400Redemption.t.sol";

contract ERC1400Test is ERC1400IssuanceTest, ERC1400RedemptionTest {
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
}
