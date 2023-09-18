//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { ERC1400 } from "../../src/ERC1400/ERC1400.sol";
import { ERC1400BaseTest } from "./ERC1400BaseTest.t.sol";

abstract contract ERC1400IssuanceTest is ERC1400BaseTest {
	function testShouldFailWhenIssuingNotByIssuer() public {
		string memory errMsg = accessControlError(address(this), ERC1400MockToken.ERC1400_ISSUER_ROLE());
		vm.expectRevert(bytes(errMsg));
		ERC1400MockToken.issue(alice, 100e18, "");
	}

	function testShouldNotIssueToZeroAddress() public {
		vm.startPrank(tokenIssuer);
		vm.expectRevert("ERC1400: Invalid recipient (zero address)");
		ERC1400MockToken.issue(ZERO_ADDRESS, 100e18, "");
		vm.stopPrank();
	}

	function testShouldNotIssueZeroAmount() public {
		vm.startPrank(tokenIssuer);
		vm.expectRevert("ERC1400: zero amount");
		ERC1400MockToken.issue(alice, 0, "");
		vm.stopPrank();
	}

	function testIssueTokensByIssuer() public {
		vm.startPrank(tokenIssuer);

		///@dev check the Issued event is emitted
		vm.expectEmit(true, true, true, true);
		emit Issued(tokenIssuer, alice, 100e18, "");

		ERC1400MockToken.issue(alice, 100e18, "");

		assertEq(ERC1400MockToken.balanceOf(alice), 100e18, "Alice's total balance should be 100e18");
		assertEq(
			ERC1400MockToken.totalSupply(),
			INITIAL_SUPPLY + 100e18,
			"token total supply should be 100_000_100e18"
		);
		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, alice),
			100e18,
			"Alice's default partition balance should be 100e18"
		);
		assertEq(
			ERC1400MockToken.totalSupplyByPartition(DEFAULT_PARTITION),
			INITIAL_SUPPLY + 100e18,
			"token default partition total supply should be 100_000_100e18"
		);

		vm.stopPrank();
	}

	function testIssueByPartitionFailWhenIssuingNotByIssuer() public {
		string memory errMsg = accessControlError(address(this), ERC1400MockToken.ERC1400_ISSUER_ROLE());
		vm.expectRevert(bytes(errMsg));
		ERC1400MockToken.issueByPartition(SHARED_SPACES_PARTITION, bob, 150e18, "");
	}

	function testIssueTokenByPartitionByIssuer() public {
		vm.startPrank(tokenIssuer);

		vm.expectEmit(true, true, true, true);
		emit IssuedByPartition(SHARED_SPACES_PARTITION, bob, 150e18, "");

		ERC1400MockToken.issueByPartition(SHARED_SPACES_PARTITION, bob, 150e18, "");

		assertEq(ERC1400MockToken.balanceOf(bob), 150e18, "Bob's balance should be 150e18 tokens");
		assertEq(
			ERC1400MockToken.totalSupply(),
			INITIAL_SUPPLY + 150e18,
			"token total supply should be 100_000_150e18"
		);
		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, bob),
			0,
			"Bob's default partition balance should be 0"
		);
		assertEq(
			ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, bob),
			150e18,
			"Bob's shared space partition balance should be 150e18"
		);
		assertEq(
			ERC1400MockToken.totalSupplyByPartition(DEFAULT_PARTITION),
			INITIAL_SUPPLY,
			"token default partition total supply should be 100_000_000e18"
		);
		assertEq(
			ERC1400MockToken.totalSupplyByPartition(SHARED_SPACES_PARTITION),
			150e18,
			"token default partition total supply should be 150e18"
		);

		bytes32[] memory bobPartitions = ERC1400MockToken.partitionsOf(bob);
		assertEq(
			bobPartitions[0],
			SHARED_SPACES_PARTITION,
			"Bob's first partition should be keccack256(SHARED_SPACES_PARTITION)"
		);

		assertEq(ERC1400MockToken.totalPartitions(), 1, "Token should have a total of 1 paritions");

		vm.stopPrank();
	}
}
