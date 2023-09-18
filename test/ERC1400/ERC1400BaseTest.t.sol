//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "forge-std/Test.sol";
import { ERC1400 } from "../../src/ERC1400/ERC1400.sol";
import { ERC1400TestStorage } from "./utils/ERC1400TestStorage.sol";
import { ERC1400TestErrors } from "./utils/ERC1400TestErrors.sol";
import { SigUtils } from "../utils/SigUtils.sol";

abstract contract ERC1400BaseTest is Test, ERC1400TestStorage, ERC1400TestErrors {
	function setUp() public {
		ERC1400MockToken = new ERC1400(
			TOKEN_NAME,
			TOKEN_SYMBOL,
			TOKEN_VERSION,
			tokenAdmin,
			tokenIssuer,
			tokenRedeemer,
			tokenTransferAgent
		);
		sigUtilsContract = new SigUtils(DOMAIN_SEPARATOR, ERC1400MockToken.ERC1400_DATA_VALIDATION_TYPEHASH());

		vm.startPrank(tokenIssuer);
		issueTokens(DEFAULT_PARTITION, tokenAdmin, INITIAL_SUPPLY, "");
		vm.stopPrank();
	}

	///@dev start neccesary prank before calling this function
	function issueTokens(bytes32 partition, address to, uint256 amount, bytes memory data) internal {
		if (partition == DEFAULT_PARTITION) ERC1400MockToken.issue(to, amount, data);
		else ERC1400MockToken.issueByPartition(partition, to, amount, data);
	}

	// ///@dev start  necessary prank before calling this function
	// function redeemTokens(bytes32 partition, address from, uint256 amount, bytes memory data) internal {
	// 	if (from != address(0)) {
	// 		if (partition == DEFAULT_PARTITION) ERC1400MockToken.redeem(amount, data);
	// 		else ERC1400MockToken.redeemByPartition(partition, amount, data);
	// 	} else ERC1400MockToken.redeemFrom(from, amount, data);
	// }
}