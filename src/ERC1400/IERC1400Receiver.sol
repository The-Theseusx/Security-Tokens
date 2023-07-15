//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC1400Receiver {
	function onERC1400Received(
		bytes32 partition,
		address operator,
		address from,
		address to,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) external view returns (bytes4);

	// function onERC1400BatchReceived(
	//     address operator,
	//     address from,
	//     bytes32[] calldata partitions,
	//     uint256[] calldata values,
	//     bytes calldata data,
	//     bytes calldata operatorData
	// ) external returns (bytes4);
}
