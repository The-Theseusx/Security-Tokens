//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "forge-std/Test.sol";
import { ERC1400BaseTest } from "./ERC1400BaseTest.t.sol";
import { ERC1400SigUtils } from "./utils/ERC1400SigUtils.sol";

abstract contract ERC1400RedemptionTest is ERC1400BaseTest, ERC1400SigUtils {
	function testRedemptionShouldFailWhenNotRedeemer() public {
		///@dev @notice bad signer used
		bytes memory validationData = prepareRedemptionSignature(999, DEFAULT_PARTITION, tokenAdmin, 100e18, 0, 0);

		///@dev mock owner because they have tokens.
		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400: Invalid data");
		ERC1400MockToken.redeem(100e18, validationData);
		vm.stopPrank();
	}

	function testRedemptionAuthorizedByTokenRedeemer() public {
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
	}
}
