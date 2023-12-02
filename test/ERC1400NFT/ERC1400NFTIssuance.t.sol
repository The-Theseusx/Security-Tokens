//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import { ERC1400NFTBaseTest } from "./ERC1400NFTBaseTest.t.sol";

abstract contract ERC1400NFTIssuanceTest is ERC1400NFTBaseTest {
	uint256 public newTokenId = 4;

	function testShouldFailWhenIssuingNotByIssuer() public {
		string memory errMsg = accessControlError(address(this), ERC1400NFTMockToken.ERC1400_NFT_ISSUER_ROLE());
		vm.expectRevert(bytes(errMsg));
		ERC1400NFTMockToken.issue(alice, newTokenId, "");
	}

	function testShouldNotIssueToZeroAddress() public {
		vm.startPrank(tokenIssuer);
		vm.expectRevert("ERC1400NFT: Invalid recipient (zero address)");
		ERC1400NFTMockToken.issue(ZERO_ADDRESS, 100e18, "");
		vm.stopPrank();
	}

	function testShouldNotReIssueExistingTokenId() public {
		vm.startPrank(tokenIssuer);
		vm.expectRevert("ERC1400NFT: Token already exists");
		ERC1400NFTMockToken.issue(alice, ADMIN_INITIAL_TOKEN_ID, "");
		vm.stopPrank();
	}

	function testShouldNotIssueWhenIssuanceDisabled() public {
		vm.startPrank(tokenAdmin);
		ERC1400NFTMockToken.disableIssuance();
		vm.stopPrank();

		vm.startPrank(tokenIssuer);
		vm.expectRevert("ERC1400NFT: Token is not issuable");
		ERC1400NFTMockToken.issue(alice, newTokenId, "");
		vm.stopPrank();
	}

	function testShouldNotIssueTokensToNonERC1400NFTReceiverImplementer() public {
		vm.startPrank(tokenIssuer);
		vm.expectRevert("ERC1400NFT: transfer to non ERC1400NFTReceiver implementer");
		ERC1400NFTMockToken.issue(address(nonERC1400NFTReceivableContract), newTokenId, "");
		vm.stopPrank();
	}

	function testShouldIssueTokensToERC1400NFTReceiverImplementer() public {
		vm.startPrank(tokenIssuer);

		vm.expectEmit(true, true, true, true);
		emit Issued(tokenIssuer, address(ERC1400NFTReceivableContract), newTokenId, "");

		ERC1400NFTMockToken.issue(address(ERC1400NFTReceivableContract), newTokenId, "");

		vm.stopPrank();

		assertEq(
			ERC1400NFTMockToken.balanceOf(address(ERC1400NFTReceivableContract)),
			1,
			"The ERC1400NFTReceivableContract total balance should be 1"
		);

		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(DEFAULT_PARTITION, address(ERC1400NFTReceivableContract)),
			1,
			"The ERC1400NFTReceivableContract default partition balance should be 1"
		);

		assertEq(
			ERC1400NFTMockToken.ownerOf(newTokenId),
			address(ERC1400NFTReceivableContract),
			"The ERC1400NFTReceiverImplementer should be the owner of the token"
		);

		assertEq(
			ERC1400NFTMockToken.partitionOfToken(newTokenId),
			DEFAULT_PARTITION,
			"The token should be in the default partition"
		);
	}

	function testIssueTokensByIssuer() public {
		///@dev note, Alice was given tokenId 2 on the shared spaces partition in the setup function
		vm.startPrank(tokenIssuer);

		///@dev check the Issued event is emitted
		vm.expectEmit(true, true, true, true);
		emit Issued(tokenIssuer, alice, newTokenId, "");

		ERC1400NFTMockToken.issue(alice, newTokenId, "");
		vm.stopPrank();

		assertEq(ERC1400NFTMockToken.balanceOf(alice), 2, "Alice's total balance should be 2");

		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(DEFAULT_PARTITION, alice),
			1,
			"Alice's default partition balance should be 1"
		);
		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, alice),
			1,
			"Alice's shared spaces partition balance should be 1"
		);
		assertEq(ERC1400NFTMockToken.ownerOf(newTokenId), alice, "Alice should be the owner of the token");

		assertEq(
			ERC1400NFTMockToken.partitionOfToken(newTokenId),
			DEFAULT_PARTITION,
			"The token should be in the default partition"
		);
	}

	function testIssueByPartitionFailWhenIssuingNotByIssuer() public {
		string memory errMsg = accessControlError(address(this), ERC1400NFTMockToken.ERC1400_NFT_ISSUER_ROLE());
		vm.expectRevert(bytes(errMsg));
		ERC1400NFTMockToken.issueByPartition(SHARED_SPACES_PARTITION, bob, newTokenId, "");
	}

	function testShouldNotIssueByPartitionWhenIssuanceDisabled() public {
		vm.startPrank(tokenAdmin);
		ERC1400NFTMockToken.disableIssuance();
		vm.stopPrank();

		vm.startPrank(tokenIssuer);
		vm.expectRevert("ERC1400NFT: Token is not issuable");
		ERC1400NFTMockToken.issueByPartition(SHARED_SPACES_PARTITION, alice, newTokenId, "");
		vm.stopPrank();
	}

	function testShouldNotIssueByPartitionToNonERC1400NFTReceiverImplementer() public {
		vm.startPrank(tokenIssuer);
		vm.expectRevert("ERC1400NFT: transfer to non ERC1400NFTReceiver implementer");
		ERC1400NFTMockToken.issueByPartition(
			SHARED_SPACES_PARTITION,
			address(nonERC1400NFTReceivableContract),
			newTokenId,
			""
		);
		vm.stopPrank();
	}

	function testIssueByPartitionToERC1400NFTReceiverImplementer() public {
		vm.startPrank(tokenIssuer);

		vm.expectEmit(true, true, true, true);
		emit IssuedByPartition(
			SHARED_SPACES_PARTITION,
			tokenIssuer,
			address(ERC1400NFTReceivableContract),
			newTokenId,
			""
		);

		ERC1400NFTMockToken.issueByPartition(
			SHARED_SPACES_PARTITION,
			address(ERC1400NFTReceivableContract),
			newTokenId,
			""
		);

		vm.stopPrank();

		assertEq(
			ERC1400NFTMockToken.balanceOf(address(ERC1400NFTReceivableContract)),
			1,
			"The ERC1400NFTReceivableContract total balance should be 1"
		);
		assertEq(
			ERC1400NFTMockToken.ownerOf(newTokenId),
			address(ERC1400NFTReceivableContract),
			"The ERC1400NFTReceiverImplementer should be the owner of the token"
		);
		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(DEFAULT_PARTITION, address(ERC1400NFTReceivableContract)),
			0,
			"The ERC1400NFTReceivableContract default partition balance should be 0"
		);
		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, address(ERC1400NFTReceivableContract)),
			1,
			"The ERC1400NFTReceivableContract shared spaces partition balance should be 1"
		);
		assertEq(
			ERC1400NFTMockToken.partitionOfToken(newTokenId),
			SHARED_SPACES_PARTITION,
			"The token should be in the shared spaces partition"
		);
	}

	function testIssueTokenByPartitionByIssuer() public {
		vm.startPrank(tokenIssuer);

		vm.expectEmit(true, true, true, true);
		emit IssuedByPartition(SHARED_SPACES_PARTITION, tokenIssuer, bob, newTokenId, "");

		ERC1400NFTMockToken.issueByPartition(SHARED_SPACES_PARTITION, bob, newTokenId, "");

		assertEq(ERC1400NFTMockToken.balanceOf(bob), 2, "Bob's balance should be 2 token");

		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(DEFAULT_PARTITION, bob),
			0,
			"Bob's default partition balance should be 0"
		);
		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, bob),
			2,
			"Bob's shared space partition balance should be 2"
		);

		bytes32[] memory bobPartitions = ERC1400NFTMockToken.partitionsOf(bob);
		assertEq(
			bobPartitions[0],
			SHARED_SPACES_PARTITION,
			"Bob's first partition should be keccack256(SHARED_SPACES_PARTITION)"
		);

		assertEq(ERC1400NFTMockToken.totalPartitions(), 1, "Token should have a total of 1 partitions");

		vm.stopPrank();
	}
}
