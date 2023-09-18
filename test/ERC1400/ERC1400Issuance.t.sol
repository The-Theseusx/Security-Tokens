//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { ERC1400 } from "../../src/ERC1400/ERC1400.sol";
import { ERC1400TestStorage } from "./utils/ERC1400TestStorage.sol";
import { ERC1400TestErrors } from "./utils/ERC1400TestErrors.sol";

abstract contract ERC1400IssuanceTest is Test, ERC1400TestStorage, ERC1400TestErrors {
	function testShouldFailWhenIssuingNotByIssuer() public {
		string memory errMsg = accessControlError(address(this), ERC1400MockToken.ERC1400_ISSUER_ROLE());
		vm.expectRevert(bytes(errMsg));
		ERC1400MockToken.issue(ALICE, 100e18, "");
	}

	function testShouldNotIssueToZeroAddress() public {
		vm.startPrank(TOKEN_ISSUER);
		vm.expectRevert("ERC1400: Invalid recipient (zero address)");
		ERC1400MockToken.issue(ZERO_ADDRESS, 100e18, "");
		vm.stopPrank();
	}

	function testShouldNotIssueZeroAmount() public {
		vm.startPrank(TOKEN_ISSUER);
		vm.expectRevert("ERC1400: zero amount");
		ERC1400MockToken.issue(ALICE, 0, "");
		vm.stopPrank();
	}

	function testIssueTokensByIssuer() public {
		vm.startPrank(TOKEN_ISSUER);

		///@dev check the Issued event is emitted
		vm.expectEmit(true, true, true, true);
		emit Issued(TOKEN_ISSUER, ALICE, 100e18, "");

		ERC1400MockToken.issue(ALICE, 100e18, "");

		assertEq(ERC1400MockToken.balanceOf(ALICE), 100e18, "Alice's total balance should be 100e18");
		assertEq(
			ERC1400MockToken.totalSupply(),
			INITIAL_SUPPLY + 100e18,
			"token total supply should be 100_000_100e18"
		);
		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, ALICE),
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
		ERC1400MockToken.issueByPartition(SHARED_SPACES_PARTITION, BOB, 150e18, "");
	}

	function testIssueTokenByPartitionByIssuer() public {
		vm.startPrank(TOKEN_ISSUER);

		vm.expectEmit(true, true, true, true);
		emit IssuedByPartition(SHARED_SPACES_PARTITION, BOB, 150e18, "");

		ERC1400MockToken.issueByPartition(SHARED_SPACES_PARTITION, BOB, 150e18, "");

		assertEq(ERC1400MockToken.balanceOf(BOB), 150e18, "Bob's balance should be 150e18 tokens");
		assertEq(
			ERC1400MockToken.totalSupply(),
			INITIAL_SUPPLY + 150e18,
			"token total supply should be 100_000_150e18"
		);
		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, BOB),
			0,
			"Bob's default partition balance should be 0"
		);
		assertEq(
			ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, BOB),
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

		bytes32[] memory bobPartitions = ERC1400MockToken.partitionsOf(BOB);
		assertEq(
			bobPartitions[0],
			SHARED_SPACES_PARTITION,
			"Bob's first partition should be keccack256(SHARED_SPACES_PARTITION)"
		);

		assertEq(ERC1400MockToken.totalPartitions(), 1, "Token should have a total of 1 paritions");

		vm.stopPrank();
	}

	///@dev start neccesary prank before calling this function
	function issueTokens(bytes32 partition, address to, uint256 amount, bytes memory data) internal {
		if (partition == DEFAULT_PARTITION) ERC1400MockToken.issue(to, amount, data);
		else ERC1400MockToken.issueByPartition(partition, to, amount, data);
	}
}
