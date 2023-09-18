//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "forge-std/Test.sol";
import { ERC1400BaseTest } from "./ERC1400BaseTest.t.sol";
import { ERC1400SigUtils } from "./utils/ERC1400SigUtils.sol";

abstract contract ERC1400RedemptionTest is ERC1400BaseTest, ERC1400SigUtils {
	function testRedemptionShouldFailWhenNotRedeemer() public {
		// string memory errMsg = accessControlError(address(this), ERC1400MockToken.ERC1400_REDEEMER_ROLE());

		///@dev @notice bad signer used
		bytes memory validationData = prepareRedemptionSignature(999, DEFAULT_PARTITION, tokenAdmin, 100e18, 0, 0);

		///@dev mock owner because they have tokens.
		vm.startPrank(tokenAdmin);
		vm.expectRevert("ERC1400: Invalid data");
		ERC1400MockToken.redeem(100e18, validationData);
		vm.stopPrank();
	}

	// function testRedemptionAuthorizedByTokenRedeemer() public {
	// 	bytes memory validationData = prepareRedemptionSignature(
	// 		TOKEN_REDEEMER_PK,
	// 		DEFAULT_PARTITION,
	// 		tokenAdmin,
	// 		100e18,
	// 		0,
	// 		0
	// 	);
	// 	address redeemer = vm.addr(TOKEN_REDEEMER_PK);
	// 	console.log("Signer: ", redeemer);
	// 	vm.startPrank(tokenAdmin);
	// 	// vm.expectRevert("ERC1400: Invalid data");
	// 	ERC1400MockToken.redeem(100e18, validationData);
	// 	vm.stopPrank();
	// }
}
