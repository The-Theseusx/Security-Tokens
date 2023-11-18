//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console2 } from "forge-std/Test.sol";
import { ERC1400NFT } from "../../src/ERC1400NFT/ERC1400NFT.sol";
import { ERC1400NFTTestStorage } from "./utils/ERC1400NFTTestStorage.sol";
import { ERC1400NFTTestErrors } from "./utils/ERC1400NFTTestErrors.sol";
import { SigUtils } from "../utils/SigUtils.sol";
import { ERC1400NFTSigUtils } from "./utils/ERC1400NFTSigUtils.sol";
import { ERC1400NFTReceiverImplementer } from "./utils/ERC1400NFTReceiverImplementer.sol";
import { NonERC1400NFTReceiverImplementer } from "./utils/NonERC1400NFTReceiverImplementer.sol";

abstract contract ERC1400NFTBaseTest is ERC1400NFTTestStorage, ERC1400NFTSigUtils, ERC1400NFTTestErrors {
	function setUp() public {
		ERC1400NFTMockToken = new ERC1400NFT(
			TOKEN_NAME,
			TOKEN_SYMBOL,
			TOKEN_BASE_URI,
			TOKEN_VERSION,
			tokenAdmin,
			tokenIssuer,
			tokenRedeemer,
			tokenTransferAgent
		);

		sigUtilsContract = new SigUtils(
			ERC1400NFTMockToken.domainSeparator(),
			ERC1400NFTMockToken.ERC1400NFT_DATA_VALIDATION_HASH()
		);
		ERC1400NFTReceivableContract = new ERC1400NFTReceiverImplementer();
		nonERC1400NFTReceivableContract = new NonERC1400NFTReceiverImplementer();
	}

	function _addControllers() internal {
		address[] memory controllers = new address[](3);
		controllers[0] = tokenController1;
		controllers[1] = tokenController2;
		controllers[2] = tokenController3;

		ERC1400NFTMockToken.addControllers(controllers);
	}
}
