//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC1400NFTReceiver {
	function onERC1400NFTReceived(
		bytes32 partition,
		address operator,
		address from,
		address to,
		uint256 tokenId,
		bytes calldata data,
		bytes calldata operatorData
	) external view returns (bytes4);

	// function onERC1400BatchReceived(
	//     address operator,
	//     address from,
	//     bytes32[] calldata partitions,
	//     uint256[] calldata tokenIds,
	//     bytes calldata data,
	//     bytes calldata operatorData
	// ) external returns (bytes4);
}
