//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC1644 {
	// Controller Operation
	function isControllable() external view returns (bool);

	function controllerTransfer(
		address from,
		address to,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) external;

	function controllerRedeem(
		address tokenHolder,
		uint256 value,
		bytes calldata data,
		bytes calldata operatorData
	) external;

	// Controller Events
	event ControllerTransfer(
		address indexed controller,
		address indexed from,
		address indexed to,
		uint256 amount,
		bytes data,
		bytes operatorData
	);

	event ControllerRedemption(
		address indexed controller,
		address indexed tokenHolder,
		uint256 amount,
		bytes data,
		bytes operatorData
	);
}
