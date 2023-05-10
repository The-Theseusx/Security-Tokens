//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC1594 {
	// Issuance / Redemption Events
	event Issued(address indexed operator, address indexed to, uint256 amount, bytes data);
	event Redeemed(address indexed operator, address indexed from, uint256 amount, bytes data);

	// Transfers
	function transferWithData(address to, uint256 amount, bytes memory data) external;

	function transferFromWithData(address from, address to, uint256 amount, bytes memory data) external;

	// Token Issuance
	function isIssuable() external view returns (bool);

	function issue(address tokenHolder, uint256 amount, bytes memory data) external;

	// Token Redemption
	function redeem(uint256 amount, bytes memory data) external;

	function redeemFrom(address tokenHolder, uint256 amount, bytes memory data) external;

	// Transfer Validity
	function canTransfer(
		address to,
		uint256 amount,
		bytes memory data
	) external view returns (bool, bytes memory, bytes32);

	function canTransferFrom(
		address from,
		address to,
		uint256 amount,
		bytes memory data
	) external view returns (bool, bytes memory, bytes32);
}
