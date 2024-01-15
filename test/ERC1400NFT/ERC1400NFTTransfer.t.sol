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
}
