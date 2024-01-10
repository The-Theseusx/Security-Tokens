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
		vm.expectRevert("ERC1400NFT: nonexistent token");
		ERC1400NFTMockToken.redeem(ADMIN_INITIAL_TOKEN_ID, validationData);
		vm.stopPrank();
	}

	function testErc1400NFTRedeemByPartitionShouldFailIfInvalidPartition() public {
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			0,
			0
		);

		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400NFT: nonexistent partition");
		ERC1400NFTMockToken.redeemByPartition("0x12345678", ADMIN_INITIAL_TOKEN_ID, validationData);
		vm.stopPrank();
	}

	function testErc1400NFTRedeemByPartitionShouldFailIfInvalidTokenPartition() public {
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			0,
			0
		);

		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400NFT: Invalid token partition");
		///@dev ADMIN_INITIAL_TOKEN_ID is not in SHARED_SPACES_PARTITION
		ERC1400NFTMockToken.redeemByPartition(SHARED_SPACES_PARTITION, ADMIN_INITIAL_TOKEN_ID, validationData);
		vm.stopPrank();
	}

	function testErc1400NFTRedeemByPartitionShouldFailIfNotTokenOwner() public {
		///@dev issue two new tokens to tokenAdmin
		vm.startPrank(tokenIssuer);
		_issueTokens(SHARED_SPACES_PARTITION, tokenAdmin, newTokenId_, "");
		vm.stopPrank();

		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			notTokenAdmin,
			newTokenId_,
			0,
			0
		);

		vm.startPrank(notTokenAdmin);
		vm.expectRevert("ERC1400NFT: Not token owner");
		ERC1400NFTMockToken.redeemByPartition(SHARED_SPACES_PARTITION, newTokenId_, validationData);
		vm.stopPrank();
	}

	function testErc1400NFTRedeemByPartitionShouldFailIfTokenNonExistent() public {
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			tokenAdmin,
			999,
			0,
			0
		);

		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400NFT: nonexistent token");
		ERC1400NFTMockToken.redeemByPartition(SHARED_SPACES_PARTITION, 999, validationData);
		vm.stopPrank();
	}

	function testErc1400NFTRedeemByPartitionShouldFailIfTokenAlreadyRedeemed() public {
		///@dev issue two new tokens to tokenAdmin
		vm.startPrank(tokenIssuer);
		_issueTokens(SHARED_SPACES_PARTITION, tokenAdmin, newTokenId_, "");
		vm.stopPrank();

		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			tokenAdmin,
			newTokenId_,
			0,
			0
		);

		vm.startPrank(tokenAdmin);
		ERC1400NFTMockToken.redeemByPartition(SHARED_SPACES_PARTITION, newTokenId_, validationData);
		vm.stopPrank();

		validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			tokenAdmin,
			newTokenId_,
			0,
			0
		);

		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400NFT: nonexistent token");
		ERC1400NFTMockToken.redeemByPartition(SHARED_SPACES_PARTITION, newTokenId_, validationData);
		vm.stopPrank();
	}

	function testErc1400NFTRedeemByPartitionShouldFailIfInvalidAuthorizer() public {
		bytes memory validationData = prepareRedemptionSignature(
			NOT_ADMIN_PK,
			SHARED_SPACES_PARTITION,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			0,
			0
		);

		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400NFT: Invalid data");
		ERC1400NFTMockToken.redeemByPartition(SHARED_SPACES_PARTITION, ADMIN_INITIAL_TOKEN_ID, validationData);
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
		vm.expectEmit(true, true, true, true);
		emit RedeemedByPartition(SHARED_SPACES_PARTITION, tokenAdmin, tokenAdmin, newTokenId_, validationData, "");
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

	function testErc1400NFTOperatorRedeemByPartitionShouldFailIfNotOperator() public {
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			alice,
			ALICE_INITIAL_TOKEN_ID,
			0,
			0
		);

		vm.startPrank(aliceOperator);
		vm.expectRevert("ERC1400NFT: operator not authorized");
		ERC1400NFTMockToken.operatorRedeemByPartition(
			SHARED_SPACES_PARTITION,
			alice,
			ALICE_INITIAL_TOKEN_ID,
			validationData,
			""
		);
		vm.stopPrank();
	}

	function testErc1400NFTOperatorRedeemByPartitionShouldFailIfNotTokenOwner() public {
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			notTokenAdmin,
			ALICE_INITIAL_TOKEN_ID,
			0,
			0
		);

		vm.startPrank(aliceOperator);
		vm.expectRevert("ERC1400NFT: Not token owner");
		ERC1400NFTMockToken.operatorRedeemByPartition(
			SHARED_SPACES_PARTITION,
			notTokenAdmin,
			ALICE_INITIAL_TOKEN_ID,
			validationData,
			""
		);
		vm.stopPrank();
	}

	function testErc1400NFTOperatorRedeemByPartitionShouldFailIfTokenNonExistent() public {
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			alice,
			999,
			0,
			0
		);

		vm.startPrank(aliceOperator);
		vm.expectRevert("ERC1400NFT: nonexistent token");
		ERC1400NFTMockToken.operatorRedeemByPartition(SHARED_SPACES_PARTITION, alice, 999, validationData, "");
		vm.stopPrank();
	}

	function testErc1400NFTOperatorRedeemByPartitionShouldFailIfTokenAlreadyRedeemed() public {
		vm.startPrank(tokenIssuer);
		_issueTokens(SHARED_SPACES_PARTITION, alice, newTokenId_, "");
		vm.stopPrank();

		vm.startPrank(alice);
		ERC1400NFTMockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, aliceOperator);
		vm.stopPrank();

		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			alice,
			newTokenId_,
			0,
			0
		);

		vm.startPrank(aliceOperator);
		ERC1400NFTMockToken.operatorRedeemByPartition(SHARED_SPACES_PARTITION, alice, newTokenId_, validationData, "");
		vm.stopPrank();

		validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			alice,
			newTokenId_,
			0,
			0
		);

		vm.startPrank(aliceOperator);
		vm.expectRevert("ERC1400NFT: nonexistent token");
		ERC1400NFTMockToken.operatorRedeemByPartition(SHARED_SPACES_PARTITION, alice, newTokenId_, validationData, "");
		vm.stopPrank();
	}

	function testErc1400NFTOperatorRedeemByPartitionShouldFailIfInvalidAuthorizer() public {
		vm.startPrank(alice);
		ERC1400NFTMockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, aliceOperator);
		vm.stopPrank();

		bytes memory validationData = prepareRedemptionSignature(
			NOT_ADMIN_PK,
			SHARED_SPACES_PARTITION,
			alice,
			ALICE_INITIAL_TOKEN_ID,
			0,
			0
		);

		vm.startPrank(aliceOperator);
		vm.expectRevert("ERC1400NFT: Invalid data");
		ERC1400NFTMockToken.operatorRedeemByPartition(
			SHARED_SPACES_PARTITION,
			alice,
			ALICE_INITIAL_TOKEN_ID,
			validationData,
			""
		);
		vm.stopPrank();
	}

	function testErc1400NFTOperatorRedeemByPartition() public {
		vm.startPrank(alice);
		ERC1400NFTMockToken.authorizeOperator(aliceOperator);
		vm.stopPrank();

		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			alice,
			ALICE_INITIAL_TOKEN_ID,
			0,
			0
		);

		vm.startPrank(aliceOperator);
		vm.expectEmit(true, true, true, true);
		emit RedeemedByPartition(
			SHARED_SPACES_PARTITION,
			aliceOperator,
			alice,
			ALICE_INITIAL_TOKEN_ID,
			validationData,
			""
		);
		ERC1400NFTMockToken.operatorRedeemByPartition(
			SHARED_SPACES_PARTITION,
			alice,
			ALICE_INITIAL_TOKEN_ID,
			validationData,
			""
		);
		vm.stopPrank();

		assertFalse(ERC1400NFTMockToken.exists(ALICE_INITIAL_TOKEN_ID), "The tokenAdmin should no longer exist");
	}

	function testErc1400NFTControllerRedeemShouldFailIfCallerNotOperator() public {
		vm.startPrank(notTokenAdmin);
		vm.expectRevert("ERC1400NFT: not a controller");
		ERC1400NFTMockToken.controllerRedeem(tokenAdmin, ADMIN_INITIAL_TOKEN_ID, "", "");
		vm.stopPrank();
	}

	function testErc1400NFTControllerRedeemShouldFailIfUserHasNoTokens() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		vm.startPrank(tokenController1);
		vm.expectRevert("ERC1400NFT: nonexistent token");
		ERC1400NFTMockToken.controllerRedeem(tokenAdmin, newTokenId_, "", "");
		vm.stopPrank();
	}

	function testErc1400NFTControllerRedeemShouldFailIfTokenNonExistent() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		vm.startPrank(tokenController1);
		vm.expectRevert("ERC1400NFT: nonexistent token");
		ERC1400NFTMockToken.controllerRedeem(tokenAdmin, 999, "", "");
		vm.stopPrank();
	}

	function testErc1400NFTControllerRedeem() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			0,
			0
		);

		uint256 adminBalancePrior = ERC1400NFTMockToken.balanceOf(tokenAdmin);

		vm.startPrank(tokenController1);
		vm.expectEmit(true, true, true, true);
		//		emit ControllerRedemption(_msgSender(), tokenHolder, tokenId, data, operatorData);
		emit ControllerRedemption(tokenController1, tokenAdmin, ADMIN_INITIAL_TOKEN_ID, validationData, "");

		ERC1400NFTMockToken.controllerRedeem(tokenAdmin, ADMIN_INITIAL_TOKEN_ID, validationData, "");
		vm.stopPrank();

		assertFalse(ERC1400NFTMockToken.exists(ADMIN_INITIAL_TOKEN_ID), "The tokenAdmin should no longer exist");
		assertEq(
			ERC1400NFTMockToken.balanceOf(tokenAdmin),
			adminBalancePrior - 1,
			"The tokenAdmin balance should reduce by 1"
		);
	}

	function testErc1400NFTControllerRedeemByPartitionSHouldFailIfCallerNotOperator() public {
		vm.startPrank(notTokenAdmin);
		vm.expectRevert("ERC1400NFT: not a controller");
		ERC1400NFTMockToken.controllerRedeemByPartition(
			SHARED_SPACES_PARTITION,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			"",
			""
		);
		vm.stopPrank();
	}

	function testErc1400NFTControllerRedeemByPartitionShouldFailIfTokenDoesNotExist() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		vm.startPrank(tokenController1);
		vm.expectRevert("ERC1400NFT: nonexistent token");
		ERC1400NFTMockToken.controllerRedeemByPartition(SHARED_SPACES_PARTITION, tokenAdmin, newTokenId_, "", "");
		vm.stopPrank();
	}

	function testErc1400NFTControllerRedeemByPartitionShouldFailIfTokenInDifferentPartition() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		vm.startPrank(tokenController1);
		vm.expectRevert("ERC1400NFT: Invalid token partition");
		ERC1400NFTMockToken.controllerRedeemByPartition(
			SHARED_SPACES_PARTITION,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			"",
			""
		);
		vm.stopPrank();
	}

	function testErc1400NFTControllerRedeemByPartition() public {
		vm.startPrank(tokenAdmin);
		_addControllers();
		vm.stopPrank();

		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			0,
			0
		);

		uint256 adminBalancePrior = ERC1400NFTMockToken.balanceOf(tokenAdmin);

		vm.startPrank(tokenController1);
		vm.expectEmit(true, true, true, true);
		//		emit ControllerRedemptionByPartition(partition, _msgSender(), tokenHolder, tokenId, data, operatorData);

		emit ControllerRedemptionByPartition(
			DEFAULT_PARTITION,
			tokenController1,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			validationData,
			""
		);
		ERC1400NFTMockToken.controllerRedeemByPartition(
			DEFAULT_PARTITION,
			tokenAdmin,
			ADMIN_INITIAL_TOKEN_ID,
			validationData,
			""
		);
		vm.stopPrank();

		assertFalse(ERC1400NFTMockToken.exists(ADMIN_INITIAL_TOKEN_ID), "The tokenAdmin should no longer exist");
		assertEq(
			ERC1400NFTMockToken.balanceOf(tokenAdmin),
			adminBalancePrior - 1,
			"The tokenAdmin balance should reduce by 1"
		);
	}
}
