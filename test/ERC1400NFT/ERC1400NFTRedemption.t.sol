//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1400NFTBaseTest } from "./ERC1400NFTBaseTest.t.sol";

abstract contract ERC1400NFTRedemptionTest is ERC1400NFTBaseTest {
	uint256 public newTokenId_ = 4;

	function testRedemptionShouldFailWhenNotAuthorized() public {
		///@dev @notice bad signer used
		bytes memory validationData = prepareRedemptionSignature(
			999,
			DEFAULT_PARTITION,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			0,
			0
		);

		///@dev mock owner because they have tokens.
		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400NFT: Invalid data");
		ERC1400NFTMockToken.redeem(ADMIN_INITIAL_TOKEN_ID, validationData);
		vm.stopPrank();
	}

	function testRedemptionShouldFailWhenNoDataPassedIn() public {
		///@dev expect a revert when no data is passed in.
		///@notice abi.decode in _validateData will fail in this case.
		vm.startPrank(tokenAdmin);
		vm.expectRevert();
		ERC1400NFTMockToken.redeem(ADMIN_INITIAL_TOKEN_ID, "");
		vm.stopPrank();
	}

	function testRedemptionShouldFailWhenSignatureDeadlinePasses() public {
		///@dev warp block.timestamp by 1 hour
		skip(1 hours);

		///@dev @notice 1 second used as deadline
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			0,
			1
		);

		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400NFT: Expired signature");
		ERC1400NFTMockToken.redeem(ADMIN_INITIAL_TOKEN_ID, validationData);
		vm.stopPrank();
	}

	function testRedemptionShouldFailWhenWrongNonceUsed() public {
		///@dev @notice wrong nonce of 5 used, instead of 0
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			5,
			0
		);

		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400NFT: Invalid data");
		ERC1400NFTMockToken.redeem(ADMIN_INITIAL_TOKEN_ID, validationData);
		vm.stopPrank();
	}

	function testRedeemShouldFailWhenNonceReused() public {
		///@dev issue two new tokens to tokenAdmin
		vm.startPrank(tokenIssuer);
		_issueTokens(DEFAULT_PARTITION, tokenAdmin, newTokenId_, "");
		_issueTokens(DEFAULT_PARTITION, tokenAdmin, newTokenId_ + 1, "");
		vm.stopPrank();

		///@notice used nonce 0
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			0,
			0
		);

		///@dev redeem ADMIN_INITIAL_TOKEN_ID
		vm.startPrank(tokenAdmin);
		ERC1400NFTMockToken.redeem(ADMIN_INITIAL_TOKEN_ID, validationData);
		vm.stopPrank();

		///@notice using nonce 1
		bytes memory validationData2 = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			newTokenId_,
			0,
			0
		);

		vm.startPrank(tokenAdmin);
		ERC1400NFTMockToken.redeem(newTokenId_, validationData2);
		vm.stopPrank();

		///@dev reusing nonce 1
		bytes memory validationData3 = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			newTokenId_ + 1,
			1,
			0
		);

		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400NFT: Invalid data");
		ERC1400NFTMockToken.redeem(newTokenId_ + 1, validationData3);
		vm.stopPrank();
	}

	function testRedemptionShouldFailWhenCallerHasNoTokens() public {
		///@dev issue two new tokens to tokenAdmin
		vm.startPrank(tokenIssuer);
		_issueTokens(DEFAULT_PARTITION, tokenAdmin, newTokenId_, "");
		vm.stopPrank();
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			notTokenAdmin,
			newTokenId_,
			0,
			0
		);

		///@dev @notice notTokenAdmin does not have any ERC1400 tokens
		vm.startPrank(notTokenAdmin);
		vm.expectRevert("ERC1400NFT: Not token owner");
		ERC1400NFTMockToken.redeem(newTokenId_, validationData);
		vm.stopPrank();
	}

	function testRedeem() public {
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			0,
			0
		);

		vm.startPrank(tokenAdmin);
		ERC1400NFTMockToken.redeem(ADMIN_INITIAL_TOKEN_ID, validationData);
		vm.stopPrank();

		assertEq(ERC1400NFTMockToken.balanceOf(tokenAdmin), 0, "The tokenAdmin balance should be 0");

		assertEq(
			ERC1400NFTMockToken.balanceOfByPartition(DEFAULT_PARTITION, tokenAdmin),
			0,
			"The tokenAdmin default partition balance should be 0"
		);

		assertFalse(ERC1400NFTMockToken.exists(ADMIN_INITIAL_TOKEN_ID), "The tokenAdmin should no longer exist");
	}

	function testRedeemShouldFailWhenAlreadyRedeemed() public {
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			0,
			0
		);

		vm.startPrank(tokenAdmin);
		ERC1400NFTMockToken.redeem(ADMIN_INITIAL_TOKEN_ID, validationData);
		vm.stopPrank();

		assertFalse(ERC1400NFTMockToken.exists(ADMIN_INITIAL_TOKEN_ID), "The tokenAdmin should no longer exist");

		validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			0,
			0
		);

		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400NFT: Token does not exist");
		ERC1400NFTMockToken.redeem(ADMIN_INITIAL_TOKEN_ID, validationData);
		vm.stopPrank();
	}

	function testErc1400NFTRedeemByPartition() public {
		///@dev issue two new tokens to tokenAdmin
		vm.startPrank(tokenIssuer);
		_issueTokens(SHARED_SPACES_PARTITION, tokenAdmin, newTokenId_, "");
		_issueTokens(SHARED_SPACES_PARTITION, tokenAdmin, newTokenId_ + 1, "");
		vm.stopPrank();

		///@notice used nonce 0
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			tokenAdmin,
			newTokenId_,
			0,
			0
		);

		///@dev redeem ADMIN_INITIAL_TOKEN_ID
		vm.startPrank(tokenAdmin);
		ERC1400NFTMockToken.redeemByPartition(SHARED_SPACES_PARTITION, newTokenId_, validationData);
		vm.stopPrank();

		///@notice using nonce 1
		bytes memory validationData2 = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			tokenAdmin,
			newTokenId_ + 1,
			0,
			0
		);

		vm.startPrank(tokenAdmin);
		ERC1400NFTMockToken.redeemByPartition(SHARED_SPACES_PARTITION, newTokenId_ + 1, validationData2);
		vm.stopPrank();
	}
}
