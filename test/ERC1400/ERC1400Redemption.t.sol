//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/Test.sol";
import { ERC1400BaseTest } from "./ERC1400BaseTest.t.sol";
import { ERC1400SigUtils } from "./utils/ERC1400SigUtils.sol";

abstract contract ERC1400RedemptionTest is ERC1400BaseTest, ERC1400SigUtils {
	/***************************************************************** redeem() *****************************************************************/
	function testRedemptionShouldFailWhenNotAuthorized() public {
		///@dev @notice bad signer used
		bytes memory validationData = prepareRedemptionSignature(999, DEFAULT_PARTITION, tokenAdmin, 100e18, 0, 0);

		///@dev mock owner because they have tokens.
		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400: Invalid data");
		ERC1400MockToken.redeem(100e18, validationData);
		vm.stopPrank();
	}

	function testRedemptionShouldFailWhenNoDataPassedIn() public {
		///@dev expect a revert when no data is passed in.
		///@notice abi.decode in _validateData will fail in this case.
		vm.startPrank(tokenAdmin);
		vm.expectRevert();
		ERC1400MockToken.redeem(100e18, "");
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
			100e18,
			0,
			1
		);

		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400: Expired signature");
		ERC1400MockToken.redeem(100e18, validationData);
		vm.stopPrank();
	}

	function testRedemptionShouldFailWhenWrongNonceUsed() public {
		///@dev @notice wrong nonce of 5 used, instead of 0
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			100e18,
			5,
			0
		);

		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400: Invalid data");
		ERC1400MockToken.redeem(100e18, validationData);
		vm.stopPrank();
	}

	function testRedemptionShouldFailWithInsufficientBalance() public {
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			notTokenAdmin,
			100e18,
			0,
			0
		);

		///@dev @notice notTokenAdmin does not have any ERC1400 tokens
		vm.startPrank(notTokenAdmin);
		vm.expectRevert("ERC1400: Insufficient balance");
		ERC1400MockToken.redeem(100e18, validationData);
		vm.stopPrank();
	}

	function testAuthorizedRedemption() public {
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			tokenAdmin,
			100e18,
			0,
			0
		);
		uint256 tokenAdminBalancePrior = ERC1400MockToken.balanceOf(tokenAdmin);
		uint256 tokenAdminDefaultPartitionBalancePrior = ERC1400MockToken.balanceOfByPartition(
			DEFAULT_PARTITION,
			tokenAdmin
		);
		uint256 tokenTotalSupplyPrior = ERC1400MockToken.totalSupply();
		uint256 tokenDefaultPartitionTotalSupplyPrior = ERC1400MockToken.totalSupplyByPartition(DEFAULT_PARTITION);
		uint256 redeemerRoleNoncePrior = ERC1400MockToken.getRoleNonce(ERC1400MockToken.ERC1400_REDEEMER_ROLE());

		vm.startPrank(tokenAdmin);

		///@dev asset the appropriate events are emitted
		vm.expectEmit(true, true, true, true);
		emit NonceSpent(ERC1400MockToken.ERC1400_REDEEMER_ROLE(), vm.addr(TOKEN_REDEEMER_PK), 0);

		vm.expectEmit(true, true, true, true);
		emit Redeemed(tokenAdmin, tokenAdmin, 100e18, validationData);
		ERC1400MockToken.redeem(100e18, validationData);
		vm.stopPrank();

		assertEq(
			ERC1400MockToken.balanceOf(tokenAdmin),
			tokenAdminBalancePrior - 100e18,
			"The user's balance should reduce by 100e18 tokens"
		);
		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, tokenAdmin),
			tokenAdminDefaultPartitionBalancePrior - 100e18,
			"The user's default partition balance should reduce by 100e18 tokens"
		);
		assertEq(
			ERC1400MockToken.totalSupply(),
			tokenTotalSupplyPrior - 100e18,
			"Token total supply should reduce by 100e18 tokens"
		);
		assertEq(
			ERC1400MockToken.totalSupplyByPartition(DEFAULT_PARTITION),
			tokenDefaultPartitionTotalSupplyPrior - 100e18,
			"Token default partition supply should reduce by 100e18 tokens"
		);
		///@dev assert the role nonce has increased by one.
		assertEq(
			ERC1400MockToken.getRoleNonce(ERC1400MockToken.ERC1400_REDEEMER_ROLE()),
			redeemerRoleNoncePrior + 1,
			"Redemption role nonce should increase by 1"
		);
	}

	/***************************************************************** redeemFrom() *****************************************************************/
	function testRedeemFromShouldFailWhenNotTokenRedeemer() public {
		string memory errMsg = accessControlError(notTokenAdmin, ERC1400MockToken.ERC1400_REDEEMER_ROLE());
		vm.startPrank(notTokenAdmin);
		vm.expectRevert(bytes(errMsg));
		ERC1400MockToken.redeemFrom(tokenAdmin, 100e18, "");
		vm.stopPrank();
	}

	function testRedeemFromShouldFailWithInsufficientBalance() public {
		///@dev @notice notTokenAdmin has no tokens
		vm.startPrank(tokenRedeemer);
		vm.expectRevert("ERC1400: Insufficient balance");
		ERC1400MockToken.redeemFrom(notTokenAdmin, 100e18, "");
		vm.stopPrank();
	}

	function testShouldRedeemFromWhenAuthorized() public {
		uint256 tokenAdminBalancePrior = ERC1400MockToken.balanceOf(tokenAdmin);
		uint256 tokenAdminDefaultPartitionBalancePrior = ERC1400MockToken.balanceOfByPartition(
			DEFAULT_PARTITION,
			tokenAdmin
		);
		uint256 tokenTotalSupplyPrior = ERC1400MockToken.totalSupply();
		uint256 tokenDefaultPartitionTotalSupplyPrior = ERC1400MockToken.totalSupplyByPartition(DEFAULT_PARTITION);

		vm.startPrank(tokenRedeemer);

		///@dev ensure the right event is emitted
		vm.expectEmit(true, true, true, true);
		emit Redeemed(tokenRedeemer, tokenAdmin, 200e18, "");

		ERC1400MockToken.redeemFrom(tokenAdmin, 200e18, "");
		vm.stopPrank();

		assertEq(
			ERC1400MockToken.balanceOf(tokenAdmin),
			tokenAdminBalancePrior - 200e18,
			"User's balance should reduce by 200e18 tokens"
		);
		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, tokenAdmin),
			tokenAdminDefaultPartitionBalancePrior - 200e18,
			"User's default partition balance should reduce by 200e18 tokens"
		);
		assertEq(
			ERC1400MockToken.totalSupply(),
			tokenTotalSupplyPrior - 200e18,
			"Token total supply should reduce by 200e18 tokens"
		);
		assertEq(
			ERC1400MockToken.totalSupplyByPartition(DEFAULT_PARTITION),
			tokenDefaultPartitionTotalSupplyPrior - 200e18,
			"Token default partition supply should reduce by 200e18 tokens"
		);
	}

	/***************************************************************** redeemByPartition() *****************************************************************/
	function testRedeemByPartitionShouldFailWithInvalidPartition() public {
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			alice,
			500e18,
			0,
			0
		);

		///@dev Alice tries to redeem 500 tokens on a non-existent partition
		vm.startPrank(alice);
		vm.expectRevert("ERC1400: nonexistent partition");
		ERC1400MockToken.redeemByPartition(bytes32("WRONG_PARTITION"), 500e18, validationData);
		vm.stopPrank();
	}

	function testRedeemByPartitionShouldFailWhenSignatureExpires() public {
		///@dev warp block.timestamp by 1 hour
		skip(1 hours);

		///@dev @notice 1 second used as deadline
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			alice,
			100e18,
			0,
			1
		);

		vm.startPrank(alice);
		vm.expectRevert("ERC1400: Expired signature");
		ERC1400MockToken.redeemByPartition(SHARED_SPACES_PARTITION, 100e18, validationData);
		vm.stopPrank();
	}

	function testRedeemByPartitionShouldFailWhenInvalidNonceUsed() public {
		///@dev @notice wrong nonce of 10 used, instead of 0
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			alice,
			100e18,
			10,
			0
		);

		vm.startPrank(alice);
		vm.expectRevert("ERC1400: Invalid data");
		ERC1400MockToken.redeemByPartition(SHARED_SPACES_PARTITION, 100e18, validationData);
		vm.stopPrank();
	}

	function testRedeemByPartitionShouldFailWhenNoDataPassedIn() public {
		///@dev expect a revert when no data is passed in.
		///@notice abi.decode in _validateData will fail in this case.
		vm.startPrank(tokenAdmin);
		vm.expectRevert();
		ERC1400MockToken.redeemByPartition(SHARED_SPACES_PARTITION, 100e18, "");
		vm.stopPrank();
	}

	function testRedeemByPartitionShouldFailWithInsufficientBalance() public {
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			SHARED_SPACES_PARTITION,
			notTokenAdmin,
			100e18,
			0,
			0
		);

		///@dev @notice notTokenAdmin does not have any ERC1400 tokens, both default and shared_space partition balance = 0
		vm.startPrank(notTokenAdmin);
		vm.expectRevert("ERC1400: Insufficient balance");
		ERC1400MockToken.redeemByPartition(SHARED_SPACES_PARTITION, 100e18, validationData);
		vm.stopPrank();
	}

	function testRedeemByPartitionShouldFailOnDefaultPartition() public {
		bytes memory validationData = prepareRedemptionSignature(
			TOKEN_REDEEMER_PK,
			DEFAULT_PARTITION,
			alice,
			100e18,
			10,
			0
		);

		vm.startPrank(alice);
		vm.expectRevert("ERC1400: Invalid data");
		ERC1400MockToken.redeemByPartition(DEFAULT_PARTITION, 100e18, validationData);
		vm.stopPrank();
	}

	///@dev test operator redemptions
}
