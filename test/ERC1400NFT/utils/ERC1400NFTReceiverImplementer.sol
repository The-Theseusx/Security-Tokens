//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1400NFTReceiver } from "../../../src/ERC1400NFT/ERC1400NFTReceiver.sol";

contract ERC1400NFTReceiverImplementer is ERC1400NFTReceiver {
	function name() public pure returns (string memory) {
		return "ERC1400NFTReceiverImplementer";
	}
}
