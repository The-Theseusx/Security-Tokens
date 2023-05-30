//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable2Step } from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { ERC165 } from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import { IERC1410 } from "./IERC1410.sol";

contract ERC1410 is IERC1410, ERC165, Ownable2Step {
	/**
	 * @dev partitioning is to group tokens into different buckets though the underlying token contract is one.
	 */

	/**
	 * @dev token total suppply irrespective of partition.
	 */
	uint256 private _totalSupply;

	/**
	 * @dev total number of partitions.
	 */
	uint256 private _totalPartitions;

	/**
	 * @dev mapping of partition to total token supply of partition.
	 */
	mapping(bytes32 => uint256) private _totalSupplyByPartition;

	/**
	 * @dev array of partitions.
	 */
	bytes32[] private _partitions;

	/**
	 * @dev mapping of partition to index in _partitions array.
	 */
	mapping(bytes32 => uint256) private _partitionIndex;

	/**
	 * @dev mapping from user to array of partitions.
	 */
	mapping(address => bytes32[]) private _partitionsOf;

	/**
	 * @dev mapping of user to mapping of partition in _partitionsOf array to index of partition in this array.
	 */
	mapping(address => mapping(bytes32 => uint256)) private _partitionIndexOfUser;

	/**
	 * @dev mapping from user to total token balances irrespective of partition.
	 */
	mapping(address => uint256) private _balances;

	/**
	 * @dev mapping from user to partition to total token balances of corresponding partition.
	 */
	mapping(address => mapping(bytes32 => uint256)) private _balancesByPartition;

	/**
	 * @dev mapping of user to partition to spender to allowance of token by partition.
	 */
	mapping(address => mapping(bytes32 => mapping(address => uint256))) private _allowanceByPartition;

	/**
	 * @dev mapping of user to partition to operator to allowance of token irrespective of partition.
	 * @notice for tokens with no partition, use this allowance.
	 */
	mapping(address => mapping(address => uint256)) private _allowance;

	/**
	 * @dev mapping of users to partition to operator to approved status of token transfer.
	 */
	mapping(address => mapping(bytes32 => mapping(address => bool))) private _approvalByPartition;

	/**
	 * @dev mapping of users to operator to approved status of token transfer irrespective of partition.
	 * @notice operators can spend tokens on behalf of users irrespective of _allowance as long as this mapping is true.
	 */
	mapping(address => mapping(address => bool)) private _approval;

	function totalSupply() public view virtual override returns (uint256) {
		return _totalSupply;
	}

	function totalSupplyByPartition(bytes32 partition) public view virtual returns (uint256) {
		return _totalSupplyByPartition[partition];
	}

	function balanceOf(address account) public view virtual override returns (uint256) {
		return _balances[account];
	}

	function balanceOfByPartition(bytes32 partition, address account) public view virtual override returns (uint256) {
		return _balancesByPartition[account][partition];
	}

	function allowance(address owner, address spender) public view virtual returns (uint256) {
		return _allowance[owner][spender];
	}

	function allowanceByPartition(
		bytes32 partition,
		address owner,
		address spender
	) public view virtual returns (uint256) {
		return _allowanceByPartition[owner][partition][spender];
	}

	function partitionsOf(address account) public view override returns (bytes32[] memory) {
		return _partitionsOf[account];
	}

	function isOperator(address operator, address account) public view override returns (bool) {
		return _approval[account][operator];
	}

	function isOperatorForPartition(
		bytes32 partition,
		address operator,
		address account
	) public view override returns (bool) {
		return _approvalByPartition[account][partition][operator];
	}

	function canTransferByPartition(
		address from,
		address to,
		bytes32 partition,
		uint256 amount,
		bytes calldata data
	) public view override returns (bytes memory, bytes32, bytes32) {
		uint256 index = _partitionIndex[partition];
		if (index == 0 && _partitions[0] != partition) return ("0x50", "ERC1410: IP", "");
		if (_balancesByPartition[from][partition] < amount) return ("0x52", "ERC1410: IPB", "");
		if (to == address(0)) return ("0x57", "ERC1410: IR", "");
		//validate data

		return ("0x51", "ERC1410: CT", "");
	}

	function authorizeOperator(address operator) public virtual override {
		_approval[msg.sender][operator] = true;
		emit AuthorizedOperator(operator, msg.sender);
	}

	function authorizeOperatorByPartition(bytes32 partition, address operator) public virtual override {
		_approvalByPartition[msg.sender][partition][operator] = true;
		emit AuthorizedOperatorByPartition(partition, operator, msg.sender);
	}

	function revokeOperator(address operator) public virtual override {
		_approval[msg.sender][operator] = false;
		emit RevokedOperator(operator, msg.sender);
	}

	function revokeOperatorByPartition(bytes32 partition, address operator) public virtual override {
		_approvalByPartition[msg.sender][partition][operator] = false;
		emit RevokedOperatorByPartition(partition, operator, msg.sender);
	}

	function issueByPartition(
		bytes32 partition,
		address account,
		uint256 amount,
		bytes calldata data
	) external override onlyOwner {
		_issueByPartition(partition, msg.sender, account, amount, data);
	}

	function _issueByPartition(
		bytes32 partition,
		address operator,
		address account,
		uint256 amount,
		bytes memory data
	) internal virtual {
		//require(_isIssuablePartition(partition, amount), "ERC1410: Not issuable partition");
		//_beforeTokenTransfer(operator, address(0), account, amount, data, "");
		_totalSupply += amount;
		_totalSupplyByPartition[partition] += amount;
		_balances[account] += amount;
		_balancesByPartition[account][partition] += amount;
		_addTokenToPartitionList(partition, account, amount);
		emit IssuedByPartition(partition, account, amount, data);
		//emit Transfer(address(0), account, amount);
	}

	function _isUserPartion(bytes32 partition, address user) internal view returns (bool) {
		bytes32[] memory partitions = _partitionsOf[user];
		uint256 index = _partitionIndexOfUser[user][partition];
		if (index == 0 && partitions[0] != partition) return false;
		return true;
	}

	function _addTokenToPartitionList(bytes32 partition, address account, uint256 amount) internal virtual {
		bytes32[] memory partitions = _partitionsOf[account];
		uint256 index = _partitionIndex[partition];

		bytes32 currentPartition = partitions[index];

		if (partition != currentPartition) {
			///partition does not exist

			//add partition to contract
			_partitionIndex[partition] = partitions.length;
			_partitions.push(partition);
			_totalPartitions += 1;

			//add partition to user
			_partitionIndexOfUser[account][partition] = _partitionsOf[account].length;
			_partitionsOf[account].push(partition);
		} else {
			///partition exists

			if (!_isUserPartion(partition, account)) {
				_partitionIndexOfUser[account][partition] = _partitionsOf[account].length;
				_partitionsOf[account].push(partition);
			}
		}
	}

	function redeemByPartition(bytes32 partition, uint256 amount, bytes calldata data) external override {
		_redeemByPartition(partition, msg.sender, msg.sender, amount, data, "");
	}

	function _redeemByPartition(
		bytes32 partition,
		address operator,
		address account,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {
		//_beforeTokenTransfer(operator, account, address(0), amount, data, operatorData);
		_balances[account] -= amount;
		_balancesByPartition[account][partition] -= amount;
		_totalSupply -= amount;
		_totalSupplyByPartition[partition] -= amount;
		emit RedeemedByPartition(partition, operator, account, amount, data, operatorData);
		//emit Transfer(account, address(0), amount);
	}

	function redeemFromByPartition(
		bytes32 partition,
		address from,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) external {
		_redeemByPartition(partition, msg.sender, from, amount, data, operatorData);
	}

	function operatorRedeemByPartition(
		bytes32 partition,
		address account,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) external override {
		require(_approvalByPartition[account][partition][msg.sender], "ERC1410: Not authorized operator");
		_redeemByPartition(partition, msg.sender, account, amount, data, operatorData);
	}

	function operatorTransferByPartition(
		bytes32 partition,
		address from,
		address to,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) external returns (bytes32) {
		require(_approvalByPartition[from][partition][msg.sender], "ERC1410: Not authorized operator");
		_transferByPartition(partition, msg.sender, from, to, amount, data, operatorData);
		return partition;
	}

	function transferByPartition(
		bytes32 partition,
		address to,
		uint256 value,
		bytes memory data
	) public virtual override returns (bytes32) {
		//validate data
		_transferByPartition(partition, msg.sender, msg.sender, to, value, data, "");
		return partition;
	}

	function transferFromByPartition(
		bytes32 partition,
		address from,
		address to,
		uint256 value,
		bytes memory data,
		bytes memory operatorData
	) public virtual returns (bytes32) {
		//spend allowance
		_transferByPartition(partition, msg.sender, from, to, value, data, operatorData);
		return partition;
	}

	function _transferByPartition(
		bytes32 partition,
		address operator,
		address from,
		address to,
		uint256 value,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {
		require(_balancesByPartition[from][partition] >= value, "ERC1410: transfer amount exceeds balance");
		require(to != address(0), "ERC1410: transfer to the zero address");

		_balancesByPartition[from][partition] -= value;

		if (_balancesByPartition[from][partition] == 0) {
			bytes32[] memory partitions = _partitionsOf[from];
			uint256 index = _partitionIndexOfUser[from][partition];
			_partitionsOf[from][index] = partitions[partitions.length - 1];
			_partitionsOf[from].pop();
		}
		if (!_isUserPartion(partition, to)) {
			_partitionIndexOfUser[to][partition] = _partitionsOf[to].length;
			_partitionsOf[to].push(partition);
		}

		_balancesByPartition[to][partition] += value;
		emit TransferByPartition(partition, operator, from, to, value, data, operatorData);
	}

	function transfer(address to, uint256 value) public virtual returns (bool) {
		_transfer(msg.sender, msg.sender, to, value, "", "");
		return true;
	}

	function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
		//spend allowance
		_transfer(msg.sender, from, to, value, "", "");
		return true;
	}

	function _transfer(
		address operator,
		address from,
		address to,
		uint256 value,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {
		require(_balances[from] >= value, "ERC1410: transfer amount exceeds balance");
		_balances[from] -= value;
		_balances[to] += value;
		//emit Transfer(operator, from, to, value, data, operatorData);
	}

	function approve(address spender, uint256 value) public virtual returns (bool) {
		_approve(msg.sender, spender, value);
		return true;
	}

	function approveByPartition(bytes32 partition, address spender, uint256 value) public virtual returns (bool) {
		_approveByPartition(partition, msg.sender, spender, value);
		return true;
	}

	function _approve(address owner, address spender, uint256 value) internal virtual {
		_allowance[owner][spender] = value;
		//emit Approval(owner, spender, value);
	}

	function _approveByPartition(bytes32 partition, address owner, address spender, uint256 value) internal virtual {
		_allowanceByPartition[owner][partition][spender] = value;
		//emit ApprovalByPartition(partition, owner, spender, value);
	}

	function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
		_approve(msg.sender, spender, _allowance[msg.sender][spender] + addedValue);
		return true;
	}

	function increaseAllowanceByPartition(
		bytes32 partition,
		address spender,
		uint256 addedValue
	) public virtual returns (bool) {
		_approveByPartition(
			partition,
			msg.sender,
			spender,
			_allowanceByPartition[msg.sender][partition][spender] + addedValue
		);
		return true;
	}

	function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
		_approve(msg.sender, spender, _allowance[msg.sender][spender] - subtractedValue);
		return true;
	}

	function decreaseAllowanceByPartition(
		bytes32 partition,
		address spender,
		uint256 subtractedValue
	) public virtual returns (bool) {
		_approveByPartition(
			partition,
			msg.sender,
			spender,
			_allowanceByPartition[msg.sender][partition][spender] - subtractedValue
		);
		return true;
	}

	function _beforeTokenTransfer(address operator, address from, address to, uint256 value) internal virtual {}

	function _afterTokenTransfer(
		address operator,
		address from,
		address to,
		uint256 value,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {}

	function _mint(address account, uint256 value, bytes memory data, bytes memory operatorData) internal virtual {
		_balances[account] += value;
		// emit Minted(operator, account, value, data, operatorData);
		// emit Transfer(address(0), account, value, data, operatorData);
	}

	function _burn(address account, uint256 value, bytes memory data, bytes memory operatorData) internal virtual {
		require(_balances[account] >= value, "ERC1410: burn amount exceeds balance");
		_balances[account] -= value;
		// emit Burned(operator, account, value, data, operatorData);
		// emit Transfer(account, address(0), value, data, operatorData);
	}

	function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
		return interfaceId == type(IERC1410).interfaceId || super.supportsInterface(interfaceId);
	}
}
