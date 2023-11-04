//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1400BaseTest } from "./ERC1400BaseTest.t.sol";

abstract contract ERC1400ApprovalTest is ERC1400BaseTest {
	function testApproveUserToSpendDefaultPartitionTokens() public {
		vm.startPrank(tokenAdmin);
		vm.expectEmit(true, true, true, true);
		emit Approval(tokenAdmin, alice, 100e18);
		ERC1400MockToken.approve(alice, 100e18);
		vm.stopPrank();

		assertEq(
			ERC1400MockToken.allowance(tokenAdmin, alice),
			100e18,
			"default partition allowance between tokenADmin and alice should be 100e18"
		);
	}

	function testApproveUserToSpendSharedSpacesPartitionTokens() public {
		vm.startPrank(alice);
		vm.expectEmit(true, true, true, true);
		emit ApprovalByPartition(SHARED_SPACES_PARTITION, alice, tokenAdmin, 2000e18);
		ERC1400MockToken.approveByPartition(SHARED_SPACES_PARTITION, tokenAdmin, 2000e18);
		vm.stopPrank();

		assertEq(
			ERC1400MockToken.allowanceByPartition(SHARED_SPACES_PARTITION, alice, tokenAdmin),
			2000e18,
			"SHARED_SPACES_PARTITION allowance between alice and tokenAdmin should be 100e18"
		);
	}
}
