//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1400NFTBaseTest } from "./ERC1400NFTBaseTest.t.sol";

abstract contract ERC1400NFTApprovalTest is ERC1400NFTBaseTest {
	function testApprovalOfTokenIdOnDefaultPartition() public {
		vm.startPrank(tokenAdmin);
		vm.expectEmit(true, true, true, true);
		emit Approval(tokenAdmin, alice, ADMIN_INITIAL_TOKEN_ID, DEFAULT_PARTITION);
		ERC1400NFTMockToken.approve(alice, ADMIN_INITIAL_TOKEN_ID);
		vm.stopPrank();

		assertEq(
			ERC1400NFTMockToken.getApproved(ADMIN_INITIAL_TOKEN_ID),
			alice,
			"Alice should be approved to spend ADMIN_INITIAL_TOKEN_ID"
		);
	}

	function testApprovalOfTokenIdOnSharedSpacesPartition() public {
		vm.startPrank(alice);
		vm.expectEmit(true, true, true, true);
		emit Approval(alice, tokenAdmin, ALICE_INITIAL_TOKEN_ID, SHARED_SPACES_PARTITION);
		ERC1400NFTMockToken.approveByPartition(SHARED_SPACES_PARTITION, tokenAdmin, ALICE_INITIAL_TOKEN_ID);
		vm.stopPrank();

		assertEq(
			ERC1400NFTMockToken.getApproved(ALICE_INITIAL_TOKEN_ID),
			tokenAdmin,
			"tokenAdmin should be approved to spend ALICE_INITIAL_TOKEN_ID"
		);
	}
}
