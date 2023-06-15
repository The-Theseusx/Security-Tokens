//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable2Step } from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EIP712 } from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import { ERC165 } from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import { IERC1410 } from "./IERC1410.sol";
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract ERC1410 is IERC1410, ERC165, EIP712, Ownable2Step {
	/**
	 * @dev tokens not belonging to any partition should use this partition
	 */
	bytes32 public constant DEFAULT_PARTITION = bytes32(0);

	/**
	 * @dev EIP712 typehash for data validation
	 */
	bytes32 public constant ERC1410_DATA_VALIDATION_HASH =
		keccak256("ERC1410ValidateData(address from,address to,uint256 amount,bytes32 partition,uint256 nonce)");

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

	/**
	 * @dev mapping of used nonces
	 */
	mapping(address => uint256) private _userNonce;

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
	 * @return the name of the token.
	 */
	function name() public view virtual returns (string memory) {
		return _name;
	}

	/**
	 * @return the symbol of the token, usually a shorter version of the name.
	 */
	function symbol() public view virtual returns (string memory) {
		return _symbol;
	}

	/**
	 * @return the number of decimals used to get its user representation.
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

	/**
	 * @return the total number of tokens in existence, irrespective of partition.
	 */
	function totalSupply() public view virtual override returns (uint256) {
		return _totalSupply;
	}

	/**
	 * @return the total number of tokens issued from a given partition, default partition inclusive.
	 */
	function totalSupplyByPartition(bytes32 partition) public view virtual returns (uint256) {
		return _totalSupplyByPartition[partition];
	}

	/**
	 * @return the total number of tokens issued from the default partition.
	 */
	function totalSupplyOfNonPartitioned() public view virtual returns (uint256) {
		return _totalSupplyByPartition[DEFAULT_PARTITION];
	}

	/**
	 * @return the total number of partitions of this token.
	 */
	function totalPartitions() public view virtual returns (uint256) {
		return _totalPartitions;
	}

	/**
	 * @return the total token balance of a user irrespective of partition.
	 */
	function balanceOf(address account) public view virtual override returns (uint256) {
		return _balances[account];
	}

	/**
	 * @return the balance of a user for a given partition, default partition inclusive.
	 */
	function balanceOfByPartition(bytes32 partition, address account) public view virtual override returns (uint256) {
		return _balancesByPartition[account][partition];
	}

	/**
	 * @return the total token balance of a user for the default partition.
	 */
	function balanceOfNonPartitioned(address account) public view virtual returns (uint256) {
		return _balancesByPartition[account][DEFAULT_PARTITION];
	}

	/**
	 * @return the allowance of a spender on the default partition.
	 */
	function allowance(address owner, address spender) public view virtual returns (uint256) {
		return _allowanceByPartition[owner][DEFAULT_PARTITION][spender];
	}

	/**
	 * @return the allowance of a spender on the partition of the tokenHolder, default partition inclusive.
	 */
	function allowanceByPartition(
		bytes32 partition,
		address owner,
		address spender
	) public view virtual returns (uint256) {
		return _allowanceByPartition[owner][partition][spender];
	}

	/**
	 * @return the list of partitions of @param account.
	 */
	function partitionsOf(address account) public view virtual override returns (bytes32[] memory) {
		return _partitionsOf[account];
	}

	/**
	 * @return if the operator address is allowed to control all tokens of a tokenHolder.
	 */
	function isOperator(address operator, address account) public view virtual override returns (bool) {
		return _approval[account][operator];
	}

	/**
	 * @return if the operator address is allowed to control tokens of a partition on behalf of the tokenHolder.
	 */
	function isOperatorForPartition(
		bytes32 partition,
		address operator,
		address account
	) public view virtual override returns (bool) {
		return _approvalByPartition[account][partition][operator];
	}

	/**
	 * @return the nonce of a user.
	 */
	function getUserNonce(address user) public view virtual returns (uint256) {
		return _userNonce[user];
	}

	/**
	* @notice Error messages:
	  -IP: Invalid partition
	  -IPB: Insufficient partition balance
	  -IR: Receiver is invalid
	  -ID: Invalid transfer data

	 * @param from token holder.
	 * @param to token recipient.
	 * @param partition token partition.
	 * @param amount token amount.
	 * @param data information attached to the transfer, by the token holder.
	 */
	function canTransferByPartition(
		address from,
		address to,
		bytes32 partition,
		uint256 amount,
		bytes calldata data
	) public view virtual override returns (bytes memory, bytes32, bytes32) {
		uint256 index = _partitionIndex[partition];
		if (_partitions[index] != partition) return ("0x50", "ERC1410: IP", "");
		if (_balancesByPartition[from][partition] < amount) return ("0x52", "ERC1410: IPB", "");
		if (to == address(0)) return ("0x57", "ERC1410: IR", "");
		if (data.length != 0) {
			if (_validateData(owner(), from, to, amount, partition, data)) {
				return ("0x51", "ERC1410: CT", "");
			}
			return ("0x50", "ERC1410: ID", "");
		}

		return ("0x51", "ERC1410: CT", "");
	}

	/**
	 * @notice authorize an operator to use msg.sender's tokens irrespective of partitions.
	 * @notice this grants permission to the operator to transfer ALL tokens of msg.sender.
	 * @notice this includes burning tokens on behalf of the token holder.
	 * @param operator address to authorize as operator for caller.
	 */
	function authorizeOperator(address operator) public virtual override {
		_approval[msg.sender][operator] = true;
		emit AuthorizedOperator(operator, msg.sender);
	}

	/**
	 * @notice authorize an operator to use msg.sender's tokens of a given partition.
	 * @notice this grants permission to the operator to transfer tokens of msg.sender for a given partition.
	 * @notice this includes burning tokens on behalf of the token holder.
	 * @param partition the token partition.
	 * @param operator address to authorize as operator for caller.
	 */
	function authorizeOperatorByPartition(bytes32 partition, address operator) public virtual override {
		_approvalByPartition[msg.sender][partition][operator] = true;
		emit AuthorizedOperatorByPartition(partition, operator, msg.sender);
	}

	/**
	 * @notice revoke an operator's rights to use msg.sender's tokens irrespective of partitions.
	 * @notice this will revoke ALL operator rights of the msg.sender however,
	 * @notice if the operator has been authorized to spend from a partition, this will not revoke those rights.
	 * @notice see 'revokeOperatorByPartition' to revoke partition specific rights.
	 * @param operator address to revoke as operator for caller.
	 */
	function revokeOperator(address operator) public virtual override {
		_approval[msg.sender][operator] = false;
		emit RevokedOperator(operator, msg.sender);
	}

	/**
	 * @notice revoke an operator's rights to use msg.sender's tokens of a given partition.
	 * @notice this will revoke ALL operator rights of the msg.sender for a given partition.
	 * @param partition the token partition.
	 * @param operator address to revoke as operator for caller.
	 */
	function revokeOperatorByPartition(bytes32 partition, address operator) public virtual override {
		_approvalByPartition[msg.sender][partition][operator] = false;
		emit RevokedOperatorByPartition(partition, operator, msg.sender);
	}

	/**
	 * @notice allows a user to revoke all the rights of their operators in a single transaction.
	 * @notice this will revoke ALL operator rights for ALL partitions of msg.sender.
	 * @param operators addresses to revoke as operators for caller.
	 */
	function revokeOperators(address[] calldata operators) public virtual {
		bytes32[] memory partitions = partitionsOf(msg.sender);
		uint256 userPartitionCount = partitions.length;
		uint256 operatorCount = operators.length;
		uint256 i;
		uint256 j;
		for (; i < userPartitionCount; ) {
			for (; j < operatorCount; ) {
				if (isOperatorForPartition(partitions[i], operators[j], msg.sender)) {
					revokeOperatorByPartition(partitions[i], operators[j]);
				}

				if (isOperator(operators[j], msg.sender)) {
					revokeOperator(operators[j]);
				}

				unchecked {
					++j;
				}
			}

			unchecked {
				++i;
			}
		}
	}

	/**
	 * @notice allows the owner to issue tokens to an account from a specific partition aside from the default partition.
	 * @param partition the token partition.
	 * @param account the address to issue tokens to.
	 * @param amount the amount of tokens to issue.
	 * @param data additional data attached to the issue.
	 */
	function issueByPartition(
		bytes32 partition,
		address account,
		uint256 amount,
		bytes calldata data
	) public virtual override onlyOwner {
		require(partition != DEFAULT_PARTITION, "ERC1410: Invalid partition (DEFAULT_PARTITION)");
		_issueByPartition(partition, account, amount, data);
	}

	/**
	 * @notice allows the owner to issue tokens to an account from the default partition.
	 * @notice since owner is the only one who can issue tokens, no need to validate data as a signature?
	 * @param account the address to issue tokens to.
	 * @param amount the amount of tokens to issue.
	 * @param data additional data attached to the issue.
	 */
	function issue(address account, uint256 amount, bytes calldata data) public virtual onlyOwner {
		_issue(account, amount, data);
	}

	/**
	 * @param partition the token partition.
	 * @param user the address to check if it is the owner of the partition.
	 * @return true if the user is the owner of the partition, false otherwise.
	 */
	function isUserPartition(bytes32 partition, address user) public view virtual returns (bool) {
		bytes32[] memory partitions = _partitionsOf[user];
		uint256 index = _partitionIndexOfUser[user][partition];
		return partition == partitions[index];
	}

	/**
	 * @notice allows users to redeem token. Should this be restricted to the owner?
	 * @param partition the token partition to reddem from, this could be the defaul partition.
	 * @param amount the amount of tokens to redeem.
	 * @param data additional data attached to the transfer.
	 */
	function redeemByPartition(bytes32 partition, uint256 amount, bytes calldata data) public virtual override {
		_redeemByPartition(partition, msg.sender, msg.sender, amount, data, "");
	}

	/**
	 * @param partition the token partition to redeem, this could be the default partition.
	 * @param account the address to redeem from
	 * @param amount the amount to redeem
	 * @param data redeem data.
	 * @param operatorData additional data attached by the operator (if any)
	 * @notice since msg.sender is supposed to be an authorized operator,
	 * @param data and @param operatorData would be 0x unless the operator wishes to send additional metadata.
	 */
	function operatorRedeemByPartition(
		bytes32 partition,
		address account,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) public virtual override {
		_redeemByPartition(partition, msg.sender, account, amount, data, operatorData);
	}

	/**
	 * @param partition the token partition to transfer
	 * @param from the address to transfer from
	 * @param to the address to transfer to
	 * @param amount the amount to transfer
	 * @param data transfer data.
	 * @param operatorData additional data attached by the operator (if any)
	 * @notice since msg.sender is supposed to be an authorized operator,
	 * @param data and @param operatorData would be 0x unless the operator wishes to send additional metadata.
	 */
	function operatorTransferByPartition(
		bytes32 partition,
		address from,
		address to,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) public virtual override returns (bytes32) {
		require(_approvalByPartition[from][partition][msg.sender], "ERC1410: Not authorized operator");
		_transferByPartition(partition, msg.sender, from, to, amount, data, operatorData);
		return partition;
	}

	/**
	 * @notice since msg.sender is the token holder, this argument would be empty ("") unless the token holder wishes to send additional metadata.
	 * @param partition the token partition to transfer
	 * @param to the address to transfer to
	 * @param amount the amount to transfer
	 * @param data transfer data.
	 */
	function transferByPartition(
		bytes32 partition,
		address to,
		uint256 amount,
		bytes calldata data
	) public virtual override returns (bytes32) {
		_transferByPartition(partition, msg.sender, msg.sender, to, amount, data, "");
		return partition;
	}

	/**
	 * @notice since an authorized body might be forcing a token transfer from a different address, this argument could be a signature authorizing the transfer.
	 * @notice in the case of a forced transfer, the operator data would be a signature authorizing the transfer hence the data must be validated.
	 * @notice if it is a normal transferFrom, the operator data would be empty ("").
	 * @param partition the token partition to transfer
	 * @param from the address to transfer from
	 * @param to the address to transfer to
	 * @param amount the amount to transfer
	 * @param data transfer data.
	 */
	function transferFromByPartition(
		bytes32 partition,
		address from,
		address to,
		uint256 amount,
		bytes calldata data
	) public virtual returns (bytes32) {
		if (data.length != 0) {
			require(_validateData(owner(), from, to, amount, partition, data), "ERC1410: Invalid data");
			++_userNonce[owner()];
			_transferByPartition(partition, msg.sender, from, to, amount, data, "");
			return partition;
		}
		_spendAllowanceByPartition(partition, from, msg.sender, amount);
		_transferByPartition(partition, msg.sender, from, to, amount, data, "");
		return partition;
	}

	/**
	 * @notice transfers from the default partition, see transferByPartition to transfer from a non-default partition.
	 * @param to the address to transfer tokens to
	 * @param amount the amount to transfer from
	 */
	function transfer(address to, uint256 amount) public virtual returns (bool) {
		_transfer(msg.sender, msg.sender, to, amount, "", "");
		return true;
	}

	/**
	 * @param from the address to transfer tokens from
	 * @param to the address to transfer tokens to
	 * @param amount the amount to transfer from
	 * @notice transfers from the default partition, see transferByPartitionFrom to transfer from a non-default partition.
	 */
	function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
		_spendAllowance(from, msg.sender, amount);
		_transfer(msg.sender, from, to, amount, "", "");
		return true;
	}

	/**
	 * @notice approve a spender to transfer tokens from the default partition.
	 * @param spender the address to approve
	 * @param amount the amount to approve
	 * @return true if successful
	 */
	function approve(address spender, uint256 amount) public virtual returns (bool) {
		_approve(msg.sender, spender, amount);
		return true;
	}

	/**
	 * @notice increase the amount of tokens that an owner has approved for a spender to transfer from the default partition.
	 * @param spender the address to approve
	 * @param addedValue the amount to increase the approval by
	 * @return true if successful
	 */
	function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
		_approve(msg.sender, spender, _allowanceByPartition[msg.sender][DEFAULT_PARTITION][spender] + addedValue);
		return true;
	}

	/**
	 * @notice decrease the amount of tokens that an owner has approved for a spender to transfer from the default partition.
	 * @param spender the address to approve
	 * @param subtractedValue the amount to decrease the approval by
	 * @return true if successful
	 */
	function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
		_approve(msg.sender, spender, _allowanceByPartition[msg.sender][DEFAULT_PARTITION][spender] - subtractedValue);
		return true;
	}

	/**
	 * @notice approve a spender to transfer tokens from any partition but the default one.
	 * @param partition the partition to approve
	 * @param spender the address to approve
	 * @param amount the amount to approve
	 * @return true if successful
	 */
	function approveByPartition(bytes32 partition, address spender, uint256 amount) public virtual returns (bool) {
		require(partition != DEFAULT_PARTITION, "ERC1410: approveByPartition default partition");
		_approveByPartition(partition, msg.sender, spender, amount);
		return true;
	}

	/**
	 * @notice increase the amount of tokens that an owner has approved for a spender to transfer from any partition but the default one.
	 * @param partition the partition to approve
	 * @param spender the address to approve
	 * @param addedValue the amount to increase the approval by
	 * @return true if successful
	 */
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

	/**
	 * @notice decrease the amount of tokens that an owner has approved for a spender to transfer from any partition but the default one.
	 * @param partition the partition to approve
	 * @param spender the address to approve
	 * @param subtractedValue the amount to decrease the approval by
	 * @return true if successful
	 */
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

	//TODO: Add on receive hook?

	// --------------------------------------------------------------- INTERNAL FUNCTIONS ---------------------------------------------------------------
	function _validateData(
		address authorizer,
		address from,
		address to,
		uint256 amount,
		bytes32 partition,
		bytes calldata signature
	) internal view virtual returns (bool) {
		///@dev prevent replay attacks...
		bytes32 structData = keccak256(
			abi.encodePacked(ERC1410_DATA_VALIDATION_HASH, from, to, amount, partition, _userNonce[authorizer])
		);
		bytes32 structDataHash = _hashTypedDataV4(structData);
		address recoveredSigner = ECDSA.recover(structDataHash, signature);

		return recoveredSigner == authorizer;
	}

	/**
	 * @notice internal function to transfer tokens from the default partition.
	 * @param operator the address performing the transfer
	 * @param from the address to transfer tokens from
	 * @param to the address to transfer tokens to
	 * @param amount the amount to transfer
	 * @param data additional data attached to the transfer
	 * @param operatorData additional data attached to the transfer by the operator (if any)
	 */
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

	/**
	 * @notice internal function to transfer tokens from any partition but the default one.
	 * @param partition the partition to transfer tokens from
	 * @param operator the address performing the transfer
	 * @param from the address to transfer tokens from
	 * @param to the address to transfer tokens to
	 * @param amount the amount to transfer
	 * @param data additional data attached to the transfer
	 * @param operatorData additional data attached to the transfer by the operator (if any)
	 */
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
		if (operator != from) {
			require(
				isOperatorForPartition(partition, operator, from) || isOperator(operator, from),
				"ERC1410: transfer operator is not an operator for partition"
			);
		}
		_beforeTokenTransfer(partition, operator, from, to, amount, data, operatorData);
		_balancesByPartition[from][partition] -= amount;

		if (!isUserPartition(partition, to)) {
			_partitionIndexOfUser[to][partition] = _partitionsOf[to].length;
			_partitionsOf[to].push(partition);
		}

		_balancesByPartition[to][partition] += amount;
		emit TransferByPartition(partition, operator, from, to, amount, data, operatorData);

		_afterTokenTransfer(partition, operator, from, to, amount, data, operatorData);
	}

	/**
	 * @notice internal function to issue tokens from any partition but the default one.
	 * @param account the address to issue tokens to
	 * @param amount the amount to issue
	 * @param data additional data attached to the issuance
	 */
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

	/**
	 * @notice internal function to issue tokens from the default partition.
	 * @param account the address to issue tokens to
	 * @param amount the amount to issue
	 * @param data additional data attached to the issuance
	 */
	function _issue(address account, uint256 amount, bytes memory data) internal virtual {
		require(account != address(0), "ERC1410: Invalid recipient (zero address)");

		_beforeTokenTransfer(DEFAULT_PARTITION, msg.sender, address(0), account, amount, data, "");
		//validate data
		_totalSupply += amount;
		unchecked {
			_balances[account] += amount;
			_balancesByPartition[account][DEFAULT_PARTITION] += amount;
			_totalSupplyByPartition[DEFAULT_PARTITION] += amount;
		}

		//emit Issued(address(0), account, amount, data);
		_afterTokenTransfer(DEFAULT_PARTITION, msg.sender, address(0), account, amount, data, "");
	}

	/**
	 * @notice internal function to redeem tokens of any partition including the default one.
	 * @param partition the partition to redeem tokens from
	 * @param operator the address performing the redemption
	 * @param account the address to redeem tokens from
	 * @param amount the amount to redeem
	 * @param data additional data attached to the redemption
	 * @param operatorData additional data attached to the redemption by the operator (if any)
	 */
	function _redeemByPartition(
		bytes32 partition,
		address operator,
		address account,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {
		_beforeTokenTransfer(partition, operator, account, address(0), amount, data, operatorData);
		require(_balancesByPartition[account][partition] >= amount, "ERC1410: Not enough balance");
		if (operator != account) {
			require(
				isOperatorForPartition(partition, operator, account) || isOperator(operator, account),
				"ERC1410: transfer operator is not an operator for partition"
			);
		}

		_balances[account] -= amount;
		_balancesByPartition[account][partition] -= amount;
		_totalSupply -= amount;
		_totalSupplyByPartition[partition] -= amount;

		emit RedeemedByPartition(partition, operator, account, amount, data, operatorData);
		_afterTokenTransfer(partition, operator, account, address(0), amount, data, operatorData);
	}

	/**
	 * @dev called during issueByPartition
	 * @notice internal function to update the contract token partition lists.
	 */
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

	/**
	 * @notice internal approve function for default partition
	 * @param owner the address that holds the tokens to be spent
	 * @param spender the address that will spend the tokens
	 * @param amount the amount of tokens to be spent
	 */
	function _approve(address owner, address spender, uint256 amount) internal virtual {
		_approveByPartition(DEFAULT_PARTITION, owner, spender, amount);
		emit Approval(owner, spender, amount, DEFAULT_PARTITION);
	}

	/**
	 * @notice internal approve function for any partition, including the default one
	 * @param partition the partition to spend tokens from
	 * @param owner the address that holds the tokens to be spent
	 * @param spender the address that will spend the tokens
	 * @param amount the amount of tokens to be spent
	 */
	function _approveByPartition(bytes32 partition, address owner, address spender, uint256 amount) internal virtual {
		_allowanceByPartition[owner][partition][spender] = amount;
		emit Approval(owner, spender, amount, partition);
	}

	/**
	 * @notice internal function to spend the allowance between two wallets of the default partition
	 * @param owner the address that holds the tokens to be spent
	 * @param spender the address that will spend the tokens
	 * @param amount the amount of tokens to be spent
	 */
	function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
		uint256 currentAllowance = allowance(owner, spender);
		if (currentAllowance != type(uint256).max) {
			require(currentAllowance >= amount, "ERC1410: insufficient allowance");
			unchecked {
				_approve(owner, spender, currentAllowance - amount);
			}
		}
	}

	/**
	 * @notice internal function to spend the allowance between two wallets of any partition, including the default one
	 * @param partition the partition to spend tokens from
	 * @param owner the address that holds the tokens to be spent
	 * @param spender the address that will spend the tokens
	 * @param amount the amount of tokens to be spent
	 */
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

	/**
	@notice hook to be called before any token transfer
	 */
	function _beforeTokenTransfer(
		bytes32 partition,
		address operator,
		address from,
		address to,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {}

	/**
	 * @notice hook to be called after any token transfer
	 */
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
