//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC1643 } from "../ERC1643/IERC1643.sol";

interface IERC1400NFT is IERC1643 {
	event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
	event RevokedOperator(address indexed operator, address indexed tokenHolder);
	event AuthorizedOperatorByPartition(
		bytes32 indexed partition,
		address indexed operator,
		address indexed tokenHolder
	);
	event RevokedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);

	// Issuance / Redemption Events
	event Issued(address indexed operator, address indexed to, uint256 tokenId, bytes data);
	event Redeemed(address indexed operator, address indexed from, uint256 tokenId, bytes data);
	event IssuedByPartition(bytes32 indexed partition, address indexed to, uint256 tokenId, bytes data);
	event RedeemedByPartition(
		bytes32 indexed partition,
		address indexed operator,
		address indexed from,
		uint256 tokenId,
		bytes data,
		bytes operatorData
	);

	// Transfer Events
	event TransferByPartition(
		bytes32 indexed fromPartition,
		address operator,
		address indexed from,
		address indexed to,
		uint256 tokenId,
		bytes data,
		bytes operatorData
	);

	// Controller Events
	event ControllerTransfer(
		address indexed controller,
		address indexed from,
		address indexed to,
		uint256 tokenId,
		bytes data,
		bytes operatorData
	);

	event ControllerRedemption(
		address indexed controller,
		address indexed tokenHolder,
		uint256 tokenId,
		bytes data,
		bytes operatorData
	);

	// Token Information
	function isIssuable() external view returns (bool);

	function balanceOf(address account) external view returns (uint256);

	function ownerOf(uint256 tokenId) external view returns (address);

	function balanceOfByPartition(bytes32 partition, address account) external view returns (uint256);

	function partitionsOf(address account) external view returns (bytes32[] memory);

	// Token Transfers
	function transferByPartition(
		bytes32 partition,
		address to,
		uint256 tokenId,
		bytes calldata data
	) external returns (bytes32);

	function operatorTransferByPartition(
		bytes32 partition,
		address from,
		address to,
		uint256 tokenId,
		bytes calldata data,
		bytes calldata operatorData
	) external returns (bytes32);

	function controllerTransfer(
		address from,
		address to,
		uint256 tokenId,
		bytes calldata data,
		bytes calldata operatorData
	) external;

	function transferWithData(address to, uint256 tokenId, bytes memory data) external;

	function transferFromWithData(address from, address to, uint256 tokenId, bytes memory data) external;

	// Transfer Validity
	function canTransferByPartition(
		address from,
		address to,
		bytes32 partition,
		uint256 tokenId,
		bytes calldata data
	) external view returns (bytes memory, bytes32, bytes32);

	function canTransfer(
		address to,
		uint256 tokenId,
		bytes memory data
	) external view returns (bool, bytes memory, bytes32);

	function canTransferFrom(
		address from,
		address to,
		uint256 tokenId,
		bytes memory data
	) external view returns (bool, bytes memory, bytes32);

	// Operator Information
	function isOperator(address operator, address account) external view returns (bool);

	function isOperatorForPartition(bytes32 partition, address operator, address account) external view returns (bool);

	// Controller Information
	function isControllable() external view returns (bool);

	// Operator Management
	function authorizeOperator(address operator) external;

	function revokeOperator(address operator) external;

	function authorizeOperatorByPartition(bytes32 partition, address operator) external;

	function revokeOperatorByPartition(bytes32 partition, address operator) external;

	// Issuance / Redemption
	function issue(address tokenHolder, uint256 tokenId, bytes memory data) external;

	function issueByPartition(bytes32 partition, address account, uint256 tokenId, bytes calldata data) external;

	function redeem(uint256 tokenId, bytes memory data) external;

	function redeemFrom(address tokenHolder, uint256 tokenId, bytes memory data) external;

	function redeemByPartition(bytes32 partition, uint256 tokenId, bytes calldata data) external;

	function operatorRedeemByPartition(
		bytes32 partition,
		address account,
		uint256 tokenId,
		bytes calldata data,
		bytes calldata operatorData
	) external;

	// Controller Operation
	function controllerRedeem(
		address tokenHolder,
		uint256 tokenId,
		bytes calldata data,
		bytes calldata operatorData
	) external;
}
