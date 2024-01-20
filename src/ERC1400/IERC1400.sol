//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import { IERC1410 } from "../ERC1410/IERC1410.sol";
import { IERC1594 } from "../ERC1594/IERC1594.sol";
import { IERC1643 } from "../ERC1643/IERC1643.sol";
import { IERC1644 } from "../ERC1644/IERC1644.sol";

interface IERC1400 is IERC1410, IERC1594, IERC1643, IERC1644 {
	// --------------------------------------------------------------- CUSTOM EVENTS --------------------------------------------------------------- //

	///@dev event emitted when tokens are transferred with data attached
	event TransferWithData(
		address indexed authorizer,
		address operator,
		address indexed from,
		address indexed to,
		uint256 amount,
		bytes data
	);
	///@dev event emitted when issuance is disabled
	event IssuanceDisabled();
	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed owner, address indexed spender, uint256 value);
	event ApprovalByPartition(
		bytes32 indexed partition,
		address indexed owner,
		address indexed spender,
		uint256 amount
	);
	event ControllerAdded(address indexed controller);
	event ControllerRemoved(address indexed controller);
	event ControllerTransferByPartition(
		bytes32 indexed partition,
		address indexed controller,
		address indexed from,
		address to,
		uint256 amount,
		bytes data,
		bytes operatorData
	);
	event ControllerRedemptionByPartition(
		bytes32 indexed partition,
		address indexed controller,
		address indexed tokenHolder,
		uint256 amount,
		bytes data,
		bytes operatorData
	);
	event ChangedPartition(
		address operator,
		bytes32 indexed partitionFrom,
		bytes32 indexed partitionTo,
		address indexed account,
		uint256 amount,
		bytes data,
		bytes operatorData
	);
	event NonceSpent(bytes32 indexed role, address indexed spender, uint256 nonceSpent);
}
