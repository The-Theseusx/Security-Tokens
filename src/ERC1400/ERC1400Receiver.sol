//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Contracts that want to accept ERC1400 tokens must inherit this contract
 */

import { IERC1400Receiver } from "./IERC1400Receiver.sol";

contract ERC1400Receiver is IERC1400Receiver {
	/**
	 * @dev See {IERC1400Receiver-onERC1400Received}.
	 *
	 * Always returns `IERC1400Receiver.onERC1400Received.selector`.
	 */
	function onERC1400Received(
		bytes32,
		address,
		address,
		address,
		uint256,
		bytes calldata,
		bytes calldata
	) public view virtual override returns (bytes4) {
		return this.onERC1400Received.selector;
	}
}
