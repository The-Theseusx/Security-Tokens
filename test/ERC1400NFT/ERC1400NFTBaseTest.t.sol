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

		vm.startPrank(tokenIssuer);
		_issueTokens(DEFAULT_PARTITION, tokenAdmin, ADMIN_INITIAL_TOKEN_ID, "");

		///@dev issue to Alice and Bob 1_000_000e18 tokens each in the shared spaces partition
		_issueTokens(SHARED_SPACES_PARTITION, alice, ALICE_INITIAL_TOKEN_ID, "");
		_issueTokens(SHARED_SPACES_PARTITION, bob, BOB_INITIAL_TOKEN_ID, "");

		vm.stopPrank();
	}

	///@dev start necessary prank before calling this function
	function _issueTokens(bytes32 partition, address to, uint256 tokenId, bytes memory data) internal {
		if (partition == DEFAULT_PARTITION) ERC1400NFTMockToken.issue(to, tokenId, data);
		else ERC1400NFTMockToken.issueByPartition(partition, to, tokenId, data);
	}

	function _addControllers() internal {
		address[] memory controllers = new address[](3);
		controllers[0] = tokenController1;
		controllers[1] = tokenController2;
		controllers[2] = tokenController3;

		ERC1400NFTMockToken.addControllers(controllers);
	}
}
