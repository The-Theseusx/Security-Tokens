//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { ERC1400TestStorage } from "./utils/ERC1400TestStorage.sol";
import { ERC1400TestErrors } from "./utils/ERC1400TestErrors.sol";

abstract contract ERC1400RedemptionTest is Test, ERC1400TestStorage, ERC1400TestErrors {
	function testRedemptionShouldFailWhenNotRedeemer() public {
		string memory errMsg = accessControlError(address(this), ERC1400MockToken.ERC1400_REDEEMER_ROLE());

		///@dev mock owner because they have tokens.
		vm.startPrank(OWNER);
		vm.expectRevert(bytes(errMsg));
		ERC1400MockToken.redeem(100, "");
		vm.stopPrank();
	}

	// ///@dev start  necessary prank before calling this function
	// function redeemTokens(bytes32 partition, address from, uint256 amount, bytes memory data) internal {
	// 	if (from != address(0)) {
	// 		if (partition == DEFAULT_PARTITION) ERC1400MockToken.redeem(amount, data);
	// 		else ERC1400MockToken.redeemByPartition(partition, amount, data);
	// 	} else ERC1400MockToken.redeemFrom(from, amount, data);
	// }
}
