//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "forge-std/Test.sol";
import { ERC1400 } from "../../src/ERC1400/ERC1400.sol";
import { ERC1400TestStorage } from "./utils/ERC1400TestStorage.sol";
import { ERC1400TestErrors } from "./utils/ERC1400TestErrors.sol";
import { SigUtils } from "../utils/SigUtils.sol";
import { ERC1400SigUtils } from "./utils/ERC1400SigUtils.sol";
import { ERC1400ReceiverImplementer } from "./utils/ERC1400ReceiverImplementer.sol";
import { NonERC1400ReceiverImplementer } from "./utils/NonERC1400ReceiverImplementer.sol";

abstract contract ERC1400BaseTest is Test, ERC1400TestStorage, ERC1400TestErrors, ERC1400SigUtils {
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
		ERC1400ReceivableContract = new ERC1400ReceiverImplementer();
		nonERC1400ReceivableContract = new NonERC1400ReceiverImplementer();

		vm.startPrank(tokenIssuer);
		_issueTokens(DEFAULT_PARTITION, tokenAdmin, INITIAL_DEFAULT_PARTITION_SUPPLY, "");

		///@dev issue to Alice and Bob 1_000_000e18 tokens each in the shared spaces partition
		_issueTokens(SHARED_SPACES_PARTITION, alice, 1_000_000e18, "");
		_issueTokens(SHARED_SPACES_PARTITION, bob, 1_000_000e18, "");

		vm.stopPrank();
	}

	///@dev start necessary prank before calling this function
	function _issueTokens(bytes32 partition, address to, uint256 amount, bytes memory data) internal {
		if (partition == DEFAULT_PARTITION) ERC1400MockToken.issue(to, amount, data);
		else ERC1400MockToken.issueByPartition(partition, to, amount, data);
	}

	function _addControllers() internal {
		address[] memory controllers = new address[](3);
		controllers[0] = tokenController1;
		controllers[1] = tokenController2;
		controllers[2] = tokenController3;

		ERC1400MockToken.addControllers(controllers);
	}
}
