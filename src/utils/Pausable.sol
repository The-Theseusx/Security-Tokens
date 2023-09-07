// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Context } from "openzeppelin-contracts/contracts/utils/Context.sol";

/**
 * @dev Contract module which allows ERC1400 token transfers to be paused and unpaused by an authorized account.
 * Pauses can be enforced on all token holders (default) or on a per-address basis (via `pauseAccount(address)`)
 * or on a per-partition basis (via `pauseByPartition(bytes32)`).

 * @notice Inspired by OpenZeppelin's Pausable contract.
 */
abstract contract Pausable is Context {
	///@dev Emitted when the pause is triggered by pauser.
	event Paused(address indexed pauser);

	///@dev Emitted when the pause is lifted by pauser.
	event Unpaused(address indexed liberator);

	///@dev Emitted when an address's funds are frozen / paused
	event AccountPaused(address indexed pauser, address indexed account);

	///@dev Emitted when an address's funds are unfrozen / unpaused
	event AccountUnpaused(address indexed liberator, address indexed account);

	///@dev Emitted when a partition's funds are frozen / paused
	event PartitionPaused(address indexed pauser, bytes32 indexed partition);

	///@dev Emitted when a partition's funds are unfrozen / unpaused
	event PartitionUnpaused(address indexed liberator, bytes32 indexed partition);

	///@dev Tracks whether the contract is paused.
	bool private _paused;

	///@dev Tracks whether an address is paused.
	mapping(address => bool) private _accountPaused;

	///@dev Tracks whether a partition is paused.
	mapping(bytes32 => bool) private _partitionPaused;

	constructor() {}

	/**
	 * @dev Modifier to make a function callable only when the contract, account and partition are not paused.
	 * @dev Recommended for general purpose functions.
	 *
	 * Requirements:
	 *
	 * - The contract, the user's account and the partition must not be paused.
	 */
	modifier whenNotPaused(address account, bytes32 partition) {
		_requireNotPaused(account, partition);
		_;
	}

	/**
	 * @dev Modifier to make a function callable only when the contract, account or is paused.
	 * @dev Recommended for general purpose functions.
	 *
	 * Requirements:
	 *
	 * - Either the contract, the user's account or the partition must be paused.
	 */
	modifier whenPaused(address account, bytes32 partition) {
		_requirePaused(account, partition);
		_;
	}

	/**
	 * @dev Modifier to make a function callable only when the token contract is not paused.
	 *
	 * Requirements:
	 *
	 * - The contract must not be paused.
	 */
	modifier whenTokenNotPaused() {
		_requireTokenNotPaused();
		_;
	}

	/**
	 * @dev Modifier to make a function callable only when the token contract is paused.
	 *
	 * Requirements:
	 *
	 * - The contract must be paused.
	 */
	modifier whenTokenPaused() {
		_requireTokenPaused();
		_;
	}

	/**
	 * @dev Modifier to make a function callable only when the address is not paused.
	 *
	 * Requirements:
	 *
	 * - The address must not be paused.
	 */
	modifier whenAccountNotPaused(address account) {
		_requireAccountNotPaused(account);
		_;
	}

	/**
	 * @dev Modifier to make a function callable only when the address is paused.
	 *
	 * Requirements:
	 *
	 * - The address must be paused.
	 */
	modifier whenAccountPaused(address account) {
		_requireAccountPaused(account);
		_;
	}

	/**
	 * @dev Modifier to make a function callable only when the partition is not paused.
	 *
	 * Requirements:
	 *
	 * - The partition must not be paused.
	 */
	modifier whenPartitionNotPaused(bytes32 partition) {
		_requirePartitionNotPaused(partition);
		_;
	}

	/**
	 * @dev Modifier to make a function callable only when the partition is paused.
	 *
	 * Requirements:
	 *
	 * - The partition must be paused.
	 */
	modifier whenPartitionPaused(bytes32 partition) {
		_requirePartitionPaused(partition);
		_;
	}

	/**
	 * @dev Returns true if the contract is paused, and false otherwise.
	 */
	function paused() public view virtual returns (bool) {
		return _paused;
	}

	/**
	 * @dev Returns true if the address is paused, and false otherwise.
	 */
	function accountPaused(address account) public view virtual returns (bool) {
		return _accountPaused[account];
	}

	/**
	 * @dev Returns true if the partition is paused, and false otherwise.
	 */
	function partitionPaused(bytes32 partition) public view virtual returns (bool) {
		return _partitionPaused[partition];
	}

	/**
	 * @dev Throws if the contract is paused.
	 */
	function _requireTokenNotPaused() internal view virtual {
		require(!paused(), "ERC1400Pausable: paused");
	}

	/**
	 * @dev Throws if the contract is not paused.
	 */
	function _requireTokenPaused() internal view virtual {
		require(paused(), "ERC1400Pausable: not paused");
	}

	function _requireAccountNotPaused(address account) internal view virtual {
		require(!accountPaused(account), "ERC1400Pausable: account paused");
	}

	function _requireAccountPaused(address account) internal view virtual {
		require(accountPaused(account), "ERC1400Pausable: account not paused");
	}

	function _requirePartitionNotPaused(bytes32 partition) internal view virtual {
		require(!partitionPaused(partition), "ERC1400Pausable: partition paused");
	}

	function _requirePartitionPaused(bytes32 partition) internal view virtual {
		require(partitionPaused(partition), "ERC1400Pausable: partition not paused");
	}

	function _requireNotPaused(address account, bytes32 partition) internal view virtual {
		_requireTokenNotPaused();
		_requireAccountNotPaused(account);
		_requirePartitionNotPaused(partition);
	}

	function _requirePaused(address account, bytes32 partition) internal view virtual {
		_requireTokenPaused();
		_requireAccountPaused(account);
		_requirePartitionPaused(partition);
	}

	/**
	 * @dev Triggers stopped state.
	 *
	 * Requirements:
	 *
	 * - The token contract must not be paused.
	 */
	function _pause() internal virtual whenTokenNotPaused {
		_paused = true;
		emit Paused(_msgSender());
	}

	/**
	 * @dev Returns to normal state.
	 *
	 * Requirements:
	 *
	 * - The token contract must be paused.
	 */
	function _unpause() internal virtual whenTokenPaused {
		_paused = false;
		emit Unpaused(_msgSender());
	}

	/**
	 * @dev Triggers stopped state for a specific address.
	 *
	 * Requirements:
	 *
	 * - The account must not be paused.
	 */
	function _pauseAccount(address account) internal virtual whenAccountNotPaused(account) {
		_accountPaused[account] = true;
		emit AccountPaused(_msgSender(), account);
	}

	/**
	 * @dev Returns to normal state for a specific address.
	 *
	 * Requirements:
	 *
	 * - The account must be paused.
	 */
	function _unpauseAccount(address account) internal virtual whenAccountPaused(account) {
		_accountPaused[account] = false;
		emit AccountUnpaused(_msgSender(), account);
	}

	/**
	 * @dev Triggers stopped state for a specific partition.
	 *
	 * Requirements:
	 *
	 * - The partition must not be paused.
	 */
	function _pausePartition(bytes32 partition) internal virtual whenPartitionNotPaused(partition) {
		_partitionPaused[partition] = true;
		emit PartitionPaused(_msgSender(), partition);
	}

	/**
	 * @dev Returns to normal state for a specific partition.
	 *
	 * Requirements:
	 *
	 * - The partition must be paused.
	 */
	function _unpausePartition(bytes32 partition) internal virtual whenPartitionPaused(partition) {
		_partitionPaused[partition] = false;
		emit PartitionUnpaused(_msgSender(), partition);
	}
}
