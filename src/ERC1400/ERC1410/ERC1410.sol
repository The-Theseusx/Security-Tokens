//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable2Step } from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EIP712 } from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import { ERC165 } from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import { IERC1410 } from "./IERC1410.sol";
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

///@dev explore the use of permit as a way to approve transactions and data validation.
contract ERC1410 is IERC1410, ERC165, EIP712, Ownable2Step {
	/**
	 * @dev tokens not belonging to any partition should use this partition
	 */
	bytes32 public constant DEFAULT_PARTITION = bytes32(0);

	/**
	 * @dev EIP712 typehash for data validation
	 */
	bytes32 public constant ERC1410_DATA_VALIDATION_HASH =
		keccak256("ERC1410ValidateData(address from,address to,uint256 amount,bytes32 partition,bytes32 operatorData)");

	/**
	 * @dev token name
	 */
	string private _name;

	/**
	 * @dev token symbol
	 */
	string private _symbol;

	/**
	 * @dev token contract version for EIP712
	 */
	string private _version;

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
	 * @dev mapping of users to partition to operator to approved status of token transfer.
	 */
	mapping(address => mapping(bytes32 => mapping(address => bool))) private _approvalByPartition;

	/**
	 * @dev mapping of users to operator to approved status of token transfer irrespective of partition.
	 * @notice operators can spend tokens on behalf of users irrespective of _allowance as long as this mapping is true.
	 */
	mapping(address => mapping(address => bool)) private _approval;

	event Transfer(
		address operator,
		address indexed from,
		address indexed to,
		uint256 amount,
		bytes32 indexed partition,
		bytes data,
		bytes operatorData
	);

	event Approval(address indexed owner, address indexed spender, uint256 amount, bytes32 indexed partition);

	event Issued(
		address indexed issuer,
		address indexed to,
		uint256 amount,
		bytes32 indexed partition,
		bytes32 operatorData
	);

	constructor(string memory name_, string memory symbol_, string memory version_) EIP712(name_, version_) {
		_name = name_;
		_symbol = symbol_;
		_version = version_;
	}

	/**
	 * @dev Returns the name of the token.
	 */
	function name() public view virtual returns (string memory) {
		return _name;
	}

	/**
	 * @dev Returns the symbol of the token, usually a shorter version of the name.
	 */
	function symbol() public view virtual returns (string memory) {
		return _symbol;
	}

	/**
	 * @dev Returns the number of decimals used to get its user representation.
	 * For example, if `decimals` equals `2`, a balance of `505` tokens should
	 * be displayed to a user as `5.05` (`505 / 10 ** 2`).
	 *
	 * Tokens usually opt for a amount of 18, imitating the relationship between
	 * Ether and Wei. This is the amount {ERC20} uses, unless this function is
	 * overridden;
	 *
	 * NOTE: This information is only used for _display_ purposes: it in
	 * no way affects any of the arithmetic of the contract, including
	 * balances and transfers.
	 */
	function decimals() public view virtual returns (uint8) {
		return 18;
	}

	function totalSupply() public view virtual override returns (uint256) {
		return _totalSupply;
	}

	function totalSupplyByPartition(bytes32 partition) public view virtual returns (uint256) {
		return _totalSupplyByPartition[partition];
	}

	function totalSupplyOfNonPartitioned() public view virtual returns (uint256) {
		return _totalSupplyByPartition[DEFAULT_PARTITION];
	}

	function totalPartitions() public view virtual returns (uint256) {
		return _totalPartitions;
	}

	/**
	 * @dev get the total token balance of a user irrespective of partition.
	 */
	function balanceOf(address account) public view virtual override returns (uint256) {
		return _balances[account];
	}

	function balanceOfByPartition(bytes32 partition, address account) public view virtual override returns (uint256) {
		return _balancesByPartition[account][partition];
	}

	function balanceOfNonPartitioned(address account) public view virtual returns (uint256) {
		return _balancesByPartition[account][DEFAULT_PARTITION];
	}

	/**
	 * @dev returns the allowance of a spender on the default partition.
	 */
	function allowance(address owner, address spender) public view virtual returns (uint256) {
		return _allowanceByPartition[owner][DEFAULT_PARTITION][spender];
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

	/**
	 * Error messages:
	 * IP: Invalid partition
	 * IPB: Insufficient partition balance
	 * IR: Receiver is invalid
	 */
	function canTransferByPartition(
		address from,
		address to,
		bytes32 partition,
		uint256 amount,
		bytes calldata data
	) public view override returns (bytes memory, bytes32, bytes32) {
		uint256 index = _partitionIndex[partition];
		if (_partitions[index] != partition) return ("0x50", "ERC1410: IP", "");
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
		require(partition != DEFAULT_PARTITION, "ERC1410: Invalid partition (DEFAULT_PARTITION)");
		_issueByPartition(partition, account, amount, data);
	}

	function issue(address account, uint256 amount, bytes calldata data) external onlyOwner {
		_issue(account, amount, data);
	}

	function isUserPartition(bytes32 partition, address user) public view returns (bool) {
		bytes32[] memory partitions = _partitionsOf[user];
		uint256 index = _partitionIndexOfUser[user][partition];
		return partition == partitions[index];
	}

	function redeemByPartition(bytes32 partition, uint256 amount, bytes calldata data) external override {
		_redeemByPartition(partition, msg.sender, msg.sender, amount, data, "");
	}

	function operatorRedeemByPartition(
		bytes32 partition,
		address account,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) external virtual override {
		_redeemByPartition(partition, msg.sender, account, amount, data, operatorData);
	}

	function operatorTransferByPartition(
		bytes32 partition,
		address from,
		address to,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) external virtual override returns (bytes32) {
		require(_approvalByPartition[from][partition][msg.sender], "ERC1410: Not authorized operator");
		//validate operator data
		_transferByPartition(partition, msg.sender, from, to, amount, data, operatorData);
		return partition;
	}

	function transferByPartition(
		bytes32 partition,
		address to,
		uint256 amount,
		bytes memory data
	) public virtual override returns (bytes32) {
		//validate data
		_transferByPartition(partition, msg.sender, msg.sender, to, amount, data, "");
		return partition;
	}

	function transferFromByPartition(
		bytes32 partition,
		address from,
		address to,
		uint256 amount,
		bytes memory data
	) public virtual returns (bytes32) {
		//validate data
		_spendAllowanceByPartition(partition, from, msg.sender, amount);
		_transferByPartition(partition, msg.sender, from, to, amount, data, "");
		return partition;
	}

	function transfer(address to, uint256 amount) public virtual returns (bool) {
		_transfer(msg.sender, msg.sender, to, amount, "", "");
		return true;
	}

	function transferWithData(address to, uint256 amount, bytes memory data) public virtual returns (bool) {
		require(data.length != 0, "ERC1410: Invalid data");
		_transfer(msg.sender, msg.sender, to, amount, data, "");
		return true;
	}

	function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
		_spendAllowance(from, msg.sender, amount);
		_transfer(msg.sender, from, to, amount, "", "");
		return true;
	}

	function transferFromWithData(
		address from,
		address to,
		uint256 amount,
		bytes memory data
	) public virtual returns (bool) {
		require(data.length != 0, "ERC1410: Invalid data");
		_spendAllowance(from, msg.sender, amount);
		_transfer(msg.sender, from, to, amount, data, "");
		return true;
	}

	function approve(address spender, uint256 amount) public virtual returns (bool) {
		_approve(msg.sender, spender, amount);
		return true;
	}

	function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
		_approve(msg.sender, spender, _allowanceByPartition[msg.sender][DEFAULT_PARTITION][spender] + addedValue);
		return true;
	}

	function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
		_approve(msg.sender, spender, _allowanceByPartition[msg.sender][DEFAULT_PARTITION][spender] - subtractedValue);
		return true;
	}

	function approveByPartition(bytes32 partition, address spender, uint256 amount) public virtual returns (bool) {
		require(partition != DEFAULT_PARTITION, "ERC1410: approveByPartition default partition");
		_approveByPartition(partition, msg.sender, spender, amount);
		return true;
	}

	function increaseAllowanceByPartition(
		bytes32 partition,
		address spender,
		uint256 addedValue
	) public virtual returns (bool) {
		require(partition != DEFAULT_PARTITION, "ERC1410: not default partition");
		_approveByPartition(
			partition,
			msg.sender,
			spender,
			_allowanceByPartition[msg.sender][partition][spender] + addedValue
		);
		return true;
	}

	function decreaseAllowanceByPartition(
		bytes32 partition,
		address spender,
		uint256 subtractedValue
	) public virtual returns (bool) {
		require(partition != DEFAULT_PARTITION, "ERC1410: not default partition");
		_approveByPartition(
			partition,
			msg.sender,
			spender,
			_allowanceByPartition[msg.sender][partition][spender] - subtractedValue
		);
		return true;
	}

	function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
		return interfaceId == type(IERC1410).interfaceId || super.supportsInterface(interfaceId);
	}

	// --------------------------------------------------------------- INTERNAL FUNCTIONS ---------------------------------------------------------------
	function _validateData(
		address authorizer,
		address from,
		address to,
		uint256 amount,
		bytes calldata signature
	) internal view virtual returns (bool) {
		///@dev prevent replay attacks...
		bytes32 structData = keccak256(abi.encodePacked(ERC1410_DATA_VALIDATION_HASH, from, to, amount));
		bytes32 structDataHash = _hashTypedDataV4(structData);
		address recoveredSigner = ECDSA.recover(structDataHash, signature);

		return recoveredSigner == authorizer;
	}

	function _transfer(
		address operator,
		address from,
		address to,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {
		require(_balancesByPartition[from][DEFAULT_PARTITION] >= amount, "ERC1410: transfer amount exceeds balance");
		require(to != address(0), "ERC1410: transfer to the zero address");

		_beforeTokenTransfer(DEFAULT_PARTITION, operator, from, to, amount, data, operatorData);
		_balancesByPartition[from][DEFAULT_PARTITION] -= amount;
		_balances[from] -= amount;

		_balancesByPartition[to][DEFAULT_PARTITION] += amount;
		_balances[to] += amount;
		emit Transfer(operator, from, to, amount, DEFAULT_PARTITION, data, operatorData);

		_afterTokenTransfer(DEFAULT_PARTITION, operator, from, to, amount, data, operatorData);
	}

	function _issueByPartition(bytes32 partition, address account, uint256 amount, bytes memory data) internal virtual {
		require(account != address(0), "ERC1410: Invalid recipient (zero address)");

		_beforeTokenTransfer(partition, msg.sender, address(0), account, amount, data, "");
		_totalSupply += amount;
		unchecked {
			_totalSupplyByPartition[partition] += amount;
			_balances[account] += amount;
			_balancesByPartition[account][partition] += amount;
		}
		_addTokenToPartitionList(partition, account);

		emit IssuedByPartition(partition, account, amount, data);
		_afterTokenTransfer(partition, msg.sender, address(0), account, amount, data, "");
	}

	function _issue(address account, uint256 amount, bytes memory data) internal virtual {
		require(account != address(0), "ERC1410: Invalid recipient (zero address)");

		_beforeTokenTransfer(DEFAULT_PARTITION, msg.sender, address(0), account, amount, data, "");
		//validate data
		_totalSupply += amount;
		unchecked {
			_balances[account] += amount;
			_balancesByPartition[account][DEFAULT_PARTITION] += amount; ///@dev tokens without partition are assigned to the global partition (0)
			_totalSupplyByPartition[DEFAULT_PARTITION] += amount;
		}

		//emit Issued(address(0), account, amount, data);
		_afterTokenTransfer(DEFAULT_PARTITION, msg.sender, address(0), account, amount, data, "");
	}

	function _transferByPartition(
		bytes32 partition,
		address operator,
		address from,
		address to,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {
		require(partition != bytes32(0), "ERC1410: Invalid partition (DEFAULT_PARTITION)");
		require(_balancesByPartition[from][partition] >= amount, "ERC1410: transfer amount exceeds balance");
		require(to != address(0), "ERC1410: transfer to the zero address");

		_beforeTokenTransfer(partition, operator, from, to, amount, data, operatorData);
		_balancesByPartition[from][partition] -= amount;

		///@dev is this necessary? if the user has no balance in this partition, no need to remove it from the list as no transfer can be done either way.
		// if (_balancesByPartition[from][partition] == 0) {
		// 	bytes32[] memory partitions = _partitionsOf[from];
		// 	uint256 index = _partitionIndexOfUser[from][partition];
		// 	_partitionsOf[from][index] = partitions[partitions.length - 1];
		// 	_partitionsOf[from].pop();
		// }
		if (!isUserPartition(partition, to)) {
			_partitionIndexOfUser[to][partition] = _partitionsOf[to].length;
			_partitionsOf[to].push(partition);
		}

		_balancesByPartition[to][partition] += amount;
		emit TransferByPartition(partition, operator, from, to, amount, data, operatorData);

		_afterTokenTransfer(partition, operator, from, to, amount, data, operatorData);
	}

	function _redeemByPartition(
		bytes32 partition,
		address operator,
		address account,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {
		_beforeTokenTransfer(partition, operator, account, address(0), amount, data, operatorData);
		//validate data and operatorData
		require(_balancesByPartition[account][partition] >= amount, "ERC1410: Not enough balance");
		require(
			_approvalByPartition[account][partition][operator] || operator == account,
			"ERC1410: Not authorized operator or owner"
		);

		_balances[account] -= amount;
		_balancesByPartition[account][partition] -= amount;
		_totalSupply -= amount;
		_totalSupplyByPartition[partition] -= amount;

		emit RedeemedByPartition(partition, operator, account, amount, data, operatorData);
		_afterTokenTransfer(partition, operator, account, address(0), amount, data, operatorData);
	}

	function _addTokenToPartitionList(bytes32 partition, address account) internal virtual {
		bytes32[] memory partitions = _partitions;
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

			if (!isUserPartition(partition, account)) {
				_partitionIndexOfUser[account][partition] = _partitionsOf[account].length;
				_partitionsOf[account].push(partition);
			}
		}
	}

	function _approve(address owner, address spender, uint256 amount) internal virtual {
		_approveByPartition(DEFAULT_PARTITION, owner, spender, amount);
		emit Approval(owner, spender, amount, DEFAULT_PARTITION);
	}

	function _approveByPartition(bytes32 partition, address owner, address spender, uint256 amount) internal virtual {
		_allowanceByPartition[owner][partition][spender] = amount;
		emit Approval(owner, spender, amount, partition);
	}

	function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
		uint256 currentAllowance = allowance(owner, spender);
		if (currentAllowance != type(uint256).max) {
			require(currentAllowance >= amount, "ERC1410: insufficient allowance");
			unchecked {
				_approve(owner, spender, currentAllowance - amount);
			}
		}
	}

	function _spendAllowanceByPartition(
		bytes32 partition,
		address owner,
		address spender,
		uint256 amount
	) internal virtual {
		uint256 currentAllowance = allowanceByPartition(partition, owner, spender);
		if (currentAllowance != type(uint256).max) {
			require(currentAllowance >= amount, "ERC1410: insufficient partition allowance");
			unchecked {
				_approveByPartition(partition, owner, spender, currentAllowance - amount);
			}
		}
	}

	function _beforeTokenTransfer(
		bytes32 partition,
		address operator,
		address from,
		address to,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {}

	function _afterTokenTransfer(
		bytes32 partition,
		address operator,
		address from,
		address to,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {}
}
