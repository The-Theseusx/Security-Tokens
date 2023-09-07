//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Contracts that want to accept ERC1400NFT tokens must inherit this contract
 */

import { IERC1400NFTReceiver } from "./IERC1400NFTReceiver.sol";

contract ERC1400NFTReceiver is IERC1400NFTReceiver {
	/**
	 * @dev See {IERC1400NFTReceiver-onERC1400NFTReceived}.
	 *
	 * Always returns `IERC1400NFTReceiver.onERC1400NFTReceived.selector`.
	 */
	function onERC1400NFTReceived(
		bytes32,
		address,
		address,
		address,
		uint256,
		bytes calldata,
		bytes calldata
	) public view virtual override returns (bytes4) {
		return this.onERC1400NFTReceived.selector;
	}
}
