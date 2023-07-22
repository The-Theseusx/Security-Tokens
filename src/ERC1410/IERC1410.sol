//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC1410 {
	// Operator Events
	event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
	event RevokedOperator(address indexed operator, address indexed tokenHolder);
	event AuthorizedOperatorByPartition(
		bytes32 indexed partition,
		address indexed operator,
		address indexed tokenHolder
	);
	event RevokedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);

	// Issuance / Redemption Events
	event IssuedByPartition(bytes32 indexed partition, address indexed to, uint256 amount, bytes data);
	event RedeemedByPartition(
		bytes32 indexed partition,
		address indexed operator,
		address indexed from,
		uint256 amount,
		bytes data,
		bytes operatorData
	);

	// Transfer Events
	event TransferByPartition(
		bytes32 indexed fromPartition,
		address operator,
		address indexed from,
		address indexed to,
		uint256 amount,
		bytes data,
		bytes operatorData
	);

	// Token Information
	function balanceOf(address account) external view returns (uint256);

	function balanceOfByPartition(bytes32 partition, address account) external view returns (uint256);

	function partitionsOf(address account) external view returns (bytes32[] memory);

	function totalSupply() external view returns (uint256);

	// Token Transfers
	function transferByPartition(
		bytes32 partition,
		address to,
		uint256 amount,
		bytes calldata data
	) external returns (bytes32);

	function operatorTransferByPartition(
		bytes32 partition,
		address from,
		address to,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) external returns (bytes32);

	function canTransferByPartition(
		address from,
		address to,
		bytes32 partition,
		uint256 amount,
		bytes calldata data
	) external view returns (bytes memory, bytes32, bytes32);

	// Operator Information
	function isOperator(address operator, address account) external view returns (bool);

	function isOperatorForPartition(bytes32 partition, address operator, address account) external view returns (bool);

	// Operator Management
	function authorizeOperator(address operator) external;

	function revokeOperator(address operator) external;

	function authorizeOperatorByPartition(bytes32 partition, address operator) external;

	function revokeOperatorByPartition(bytes32 partition, address operator) external;

	// Issuance / Redemption
	function issueByPartition(bytes32 partition, address account, uint256 amount, bytes calldata data) external;

	function redeemByPartition(bytes32 partition, uint256 amount, bytes calldata data) external;

	function operatorRedeemByPartition(
		bytes32 partition,
		address account,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) external;
}
