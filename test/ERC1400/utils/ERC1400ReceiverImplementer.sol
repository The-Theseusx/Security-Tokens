//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1400Receiver } from "../../../src/ERC1400/ERC1400Receiver.sol";

contract ERC1400ReceiverImplementer is ERC1400Receiver {
	function name() public pure returns (string memory) {
		return "ERC1400ReceiverImplementer";
	}
}
