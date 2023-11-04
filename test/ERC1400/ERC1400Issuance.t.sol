//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { ERC1400BaseTest } from "./ERC1400BaseTest.t.sol";

abstract contract ERC1400IssuanceTest is ERC1400BaseTest {
	/***************************************************************** issue() *****************************************************************/

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

	function testShouldNotIssueWhenIssuanceDisabled() public {
		vm.startPrank(tokenAdmin);
		ERC1400MockToken.disableIssuance();
		vm.stopPrank();

		vm.startPrank(tokenIssuer);
		vm.expectRevert("ERC1400: Token is not issuable");
		ERC1400MockToken.issue(alice, 100e18, "");
		vm.stopPrank();
	}

	function testShouldNotIssueTokensToNonERC1400ReceiverImplementer() public {
		vm.startPrank(tokenIssuer);
		vm.expectRevert("ERC1400: transfer to non ERC1400Receiver implementer");
		ERC1400MockToken.issue(address(nonERC1400ReceivableContract), 1000e18, "");
		vm.stopPrank();
	}

	function testShouldIssueTokensToERC1400ReceiverImplementer() public {
		vm.startPrank(tokenIssuer);

		vm.expectEmit(true, true, true, true);
		emit Issued(tokenIssuer, address(ERC1400ReceivableContract), 1000e18, "");

		ERC1400MockToken.issue(address(ERC1400ReceivableContract), 1000e18, "");

		vm.stopPrank();

		assertEq(
			ERC1400MockToken.balanceOf(address(ERC1400ReceivableContract)),
			1_000e18,
			"The ERC1400ReceivableContract total balance should be 1_000e18"
		);
		assertEq(
			ERC1400MockToken.totalSupply(),
			INITIAL_SUPPLY + 1000e18,
			"token total supply should be 100_001_00e18"
		);
		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, address(ERC1400ReceivableContract)),
			1000e18,
			"The ERC1400ReceivableContract default partition balance should be 1_000e18"
		);
		assertEq(
			ERC1400MockToken.totalSupplyByPartition(DEFAULT_PARTITION),
			INITIAL_DEFAULT_PARTITION_SUPPLY + 1000e18,
			"token default partition total supply should be 100_001_00e18"
		);
	}

	function testIssueTokensByIssuer() public {
		///@dev note, initial token supply is 100 million. 98 million in the defaul partition and 2 miliion in shared space partition
		vm.startPrank(tokenIssuer);

		///@dev check the Issued event is emitted
		vm.expectEmit(true, true, true, true);
		emit Issued(tokenIssuer, alice, 100e18, "");

		ERC1400MockToken.issue(alice, 100e18, "");
		vm.stopPrank();

		assertEq(ERC1400MockToken.balanceOf(alice), 1_000_100e18, "Alice's total balance should be 1_000_100e18");
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
			INITIAL_DEFAULT_PARTITION_SUPPLY + 100e18,
			"token default partition total supply should be 100_000_100e18"
		);
	}

	/***************************************************************** issueByPartition() *****************************************************************/

	function testIssueByPartitionFailWhenIssuingNotByIssuer() public {
		string memory errMsg = accessControlError(address(this), ERC1400MockToken.ERC1400_ISSUER_ROLE());
		vm.expectRevert(bytes(errMsg));
		ERC1400MockToken.issueByPartition(SHARED_SPACES_PARTITION, bob, 150e18, "");
	}

	function testShouldNotIssueByPartitionWhenIssuanceDisabled() public {
		vm.startPrank(tokenAdmin);
		ERC1400MockToken.disableIssuance();
		vm.stopPrank();

		vm.startPrank(tokenIssuer);
		vm.expectRevert("ERC1400: Token is not issuable");
		ERC1400MockToken.issueByPartition(SHARED_SPACES_PARTITION, alice, 100e18, "");
		vm.stopPrank();
	}

	function testShouldNotIssueByPartitionToNonERC1400ReceiverImplementer() public {
		vm.startPrank(tokenIssuer);
		vm.expectRevert("ERC1400: transfer to non ERC1400Receiver implementer");
		ERC1400MockToken.issueByPartition(SHARED_SPACES_PARTITION, address(nonERC1400ReceivableContract), 1000e18, "");
		vm.stopPrank();
	}

	function testIssueByPartitionToERC1400ReceiverImplementer() public {
		vm.startPrank(tokenIssuer);

		vm.expectEmit(true, true, true, true);
		emit IssuedByPartition(SHARED_SPACES_PARTITION, address(ERC1400ReceivableContract), 1000e18, "");

		ERC1400MockToken.issueByPartition(SHARED_SPACES_PARTITION, address(ERC1400ReceivableContract), 1000e18, "");

		vm.stopPrank();

		assertEq(
			ERC1400MockToken.balanceOf(address(ERC1400ReceivableContract)),
			1_000e18,
			"The ERC1400ReceivableContract total balance should be 1_000e18"
		);
		assertEq(
			ERC1400MockToken.totalSupply(),
			INITIAL_SUPPLY + 1000e18,
			"token total supply should be 100_001_00e18"
		);
		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, address(ERC1400ReceivableContract)),
			0,
			"The ERC1400ReceivableContract default partition balance should be 0"
		);
		assertEq(
			ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, address(ERC1400ReceivableContract)),
			1000e18,
			"The ERC1400ReceivableContract shared shapces partition balance should be 1_000e18"
		);
		assertEq(
			ERC1400MockToken.totalSupplyByPartition(SHARED_SPACES_PARTITION),
			INITIAL_SHARED_SPACES_PARTITION_SUPPLY + 1000e18,
			"token default partition total supply should be 100_001_00e18"
		);

		assertEq(
			ERC1400MockToken.totalSupplyByPartition(DEFAULT_PARTITION),
			INITIAL_DEFAULT_PARTITION_SUPPLY,
			"token default partition total supply should be 2_000_150e18"
		);
	}

	function testIssueTokenByPartitionByIssuer() public {
		vm.startPrank(tokenIssuer);

		vm.expectEmit(true, true, true, true);
		emit IssuedByPartition(SHARED_SPACES_PARTITION, bob, 150e18, "");

		ERC1400MockToken.issueByPartition(SHARED_SPACES_PARTITION, bob, 150e18, "");

		assertEq(ERC1400MockToken.balanceOf(bob), 1_000_150e18, "Bob's balance should be 1_000_150e18 tokens");
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
			1_000_150e18,
			"Bob's shared space partition balance should be 1_000_150e18"
		);
		assertEq(
			ERC1400MockToken.totalSupplyByPartition(DEFAULT_PARTITION),
			INITIAL_DEFAULT_PARTITION_SUPPLY,
			"token default partition total supply should be 98_000_000e18"
		);
		assertEq(
			ERC1400MockToken.totalSupplyByPartition(SHARED_SPACES_PARTITION),
			INITIAL_SHARED_SPACES_PARTITION_SUPPLY + 150e18,
			"token default partition total supply should be 2_000_150e18"
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
