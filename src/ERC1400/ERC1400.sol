//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable2Step } from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { ERC1643 } from "../ERC1643/ERC1643.sol";
import { EIP712 } from "openzeppelin-contracts/contracts/utils/cryptography/draft-EIP712.sol";
import { IERC1400 } from "./IERC1400.sol";
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

//TODO: @dev add controllers and controllersByPartition
//TODO: @dev review canTransfer functions
contract ERC1400 is IERC1400, Ownable2Step, ERC1643, EIP712 {
	// --------------------------------------------------------------- CONSTANTS --------------------------------------------------------------- //
	/**
	 * @dev tokens not belonging to any partition should use this partition
	 */
	bytes32 public constant DEFAULT_PARTITION = bytes32(0);

	/**
	 * @dev EIP712 typehash for data validation
	 */
	bytes32 public constant ERC1400_DATA_VALIDATION_HASH =
		keccak256("ERC1400ValidateData(address from,address to,uint256 amount,bytes32 partition,uint256 nonce)");

	// --------------------------------------------------------------- PRIVATE STATE VARIABLES --------------------------------------------------------------- //

	/**
	 * @dev should track if token is issuable or not. Should not be modifiable if false.
	 */
	bool private _isIssuable;

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
	 * @dev array of token partitions.
	 */
	bytes32[] private _partitions;

	/**
	 * @dev array of token controllers.
	 */
	address[] private _controllers;

	/**
	 * @dev mapping of partition to index in _partitions array.
	 */
	mapping(bytes32 => uint256) private _partitionIndex;

	/**
	 * @dev mapping of controller to index in _controllers array.
	 */
	mapping(address => uint256) private _controllerIndex;

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
	mapping(address => mapping(bytes32 => mapping(address => bool))) private _approvedOperatorByPartition;

	/**
	 * @dev mapping of users to operator to approved status of token transfer irrespective of partition.
	 * @notice operators can spend tokens on behalf of users irrespective of _allowance as long as this mapping is true.
	 */
	mapping(address => mapping(address => bool)) private _approvedOperator;

	/**
	 * @dev mapping of used nonces
	 */
	mapping(address => uint256) private _userNonce;

	// --------------------------------------------------------------- EVENTS --------------------------------------------------------------- //

	/**
	 * @dev event emitted when tokens are transferred with data attached
	 */
	event TransferWithData(address indexed from, address indexed to, uint256 amount, bytes data);
	/**
	 * @dev event emitted when issuance is disabled
	 */
	event IssuanceDisabled();
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

	modifier onlyController() {
		require(_controllers[_controllerIndex[msg.sender]] == msg.sender, "ERC1400: caller is not a controller");
		_;
	}

	// --------------------------------------------------------------- CONSTRUCTOR --------------------------------------------------------------- //
	constructor(string memory name_, string memory symbol_, string memory version_) EIP712(name_, version_) {
		require(bytes(name_).length != 0, "ERC1400: name required");
		require(bytes(symbol_).length != 0, "ERC1400: symbol required");
		require(bytes(version_).length != 0, "ERC1400: version required");

		_name = name_;
		_symbol = symbol_;
		_version = version_;
		_isIssuable = true;
	}

	// --------------------------------------------------------------- PUBLIC GETTERS --------------------------------------------------------------- //

	/**
	 * @dev See {IERC1594-isIssuable}.
	 */
	function isIssuable() public view virtual override returns (bool) {
		return _isIssuable;
	}

	/**
	 * @dev Check whether the token is controllable by authorized controllers.
	 * @return bool 'true' if the token is controllable
	 */
	function isControllable() public view virtual override returns (bool) {
		return !(_controllers.length == 0);
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
	 * @return if the operator address is allowed to control all tokens of a tokenHolder.
	 */
	function isOperator(address operator, address account) public view virtual override returns (bool) {
		return _approvedOperator[account][operator];
	}

	/**
	 * @return if the operator address is allowed to control tokens of a partition on behalf of the tokenHolder.
	 */
	function isOperatorForPartition(
		bytes32 partition,
		address operator,
		address account
	) public view virtual override returns (bool) {
		return _approvedOperatorByPartition[account][partition][operator];
	}

	/**
	 * @return true if @param controller is a controller of this token.
	 */
	function isController(address controller) public view virtual returns (bool) {
		uint256 controllerIndex = _controllerIndex[controller];
		return _controllers[controllerIndex] == controller;
	}

	/**
	 * @return the list of controllers of this token.
	 */
	function getControllers() public view virtual returns (address[] memory) {
		return _controllers;
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
		if (_partitions[index] != partition) return ("0x50", "ERC1400: IP", "");
		if (_balancesByPartition[from][partition] < amount) return ("0x52", "ERC1400: IPB", "");
		if (to == address(0)) return ("0x57", "ERC1400: IR", "");
		if (data.length != 0) {
			// if (_validateData(owner(), from, to, amount, partition, data)) {
			// 	return ("0x51", "ERC1400: CT", "");
			// }
			//return ("0x50", "ERC1400: ID", "");
		}

		return ("0x51", "ERC1400: CT", "");
	}

	/**
	 * @dev See {IERC1594-canTransfer}.
	 */
	function canTransfer(
		address to,
		uint256 amount,
		bytes calldata
	) public view virtual override returns (bool, bytes memory, bytes32) {
		if (balanceOfNonPartitioned(msg.sender) < amount) return (false, bytes("0x52"), bytes32(0));
		if (to == address(0)) return (false, bytes("0x57"), bytes32(0));
		// if (data.length != 0) {
		// 	if (_validateData(msg.sender, msg.sender, to, amount, DEFAULT_PARTITION, data)) return (true, bytes("0x51"), bytes32(0));
		// }
		return (true, bytes("0x51"), bytes32(0));
	}

	/**
	 * @dev See {IERC1594-canTransferFrom}.
	 */
	function canTransferFrom(
		address from,
		address to,
		uint256 amount,
		bytes calldata data
	) public view virtual override returns (bool, bytes memory, bytes32) {
		if (amount > allowance(from, msg.sender)) return (false, bytes("0x53"), bytes32(0));
		if (data.length != 0) {
			if (!_validateData(owner(), from, to, amount, DEFAULT_PARTITION, data)) {
				return (false, bytes("0x5f"), bytes32(0));
			}
		}
		return canTransfer(to, amount, data);
	}

	// --------------------------------------------------------------- TRANSFERS --------------------------------------------------------------- //

	/**
	 * @notice transfers tokens associated to the default partition, see transferByPartition to transfer from the non-default partition.
	 * @param to the address to transfer tokens to
	 * @param amount the amount to transfer from
	 */
	function transfer(address to, uint256 amount) public virtual returns (bool) {
		_transfer(msg.sender, msg.sender, to, amount, "", "");
		return true;
	}

	/**
	 *! @dev See {IERC1594-transferWithData}.amount
	 */
	function transferWithData(address to, uint256 amount, bytes calldata data) public virtual override {
		_transferWithData(msg.sender, msg.sender, to, amount, data, "");
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
		require(_approvedOperatorByPartition[from][partition][msg.sender], "ERC1400: Not authorized operator");
		_transferByPartition(partition, msg.sender, from, to, amount, data, operatorData);
		return partition;
	}

	/**
	 * @dev See {IERC1644-controllerTransfer}.
	 */
	function controllerTransfer(
		address from,
		address to,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) public virtual override onlyController {
		_transfer(msg.sender, from, to, amount, data, operatorData);

		emit ControllerTransfer(msg.sender, from, to, amount, data, operatorData);
	}

	function controllerTransferByPartition(
		bytes32 partition,
		address from,
		address to,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) public virtual onlyController {
		_transferByPartition(partition, msg.sender, from, to, amount, data, operatorData);

		emit ControllerTransferByPartition(partition, msg.sender, from, to, amount, data, operatorData);
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
	 *! @dev See {IERC1594-transferFromWithData}.
	 */
	function transferFromWithData(
		address from,
		address to,
		uint256 amount,
		bytes calldata data
	) public virtual override {
		require(_validateData(owner(), from, to, amount, DEFAULT_PARTITION, data), "ERC1400: Invalid data");
		++_userNonce[owner()];
		_transferWithData(msg.sender, from, to, amount, data, "");
	}

	/**
	 * @notice since an authorized body might be forcing a token transfer from a different address, the @param data could be a signature authorizing the transfer.
	 * @notice in the case of a forced transfer, the data would be a signature authorizing the transfer hence the data must be validated.
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
			//require(_validateData(owner(), from, to, amount, partition, data), "ERC1400: Invalid data");
			++_userNonce[owner()];
			_transferByPartition(partition, msg.sender, from, to, amount, data, "");
			return partition;
		}
		_spendAllowanceByPartition(partition, from, msg.sender, amount);
		_transferByPartition(partition, msg.sender, from, to, amount, data, "");
		return partition;
	}

	// -------------------------------------------- APPROVALS, ALLOWANCES & OPERATORS -------------------------------------------- //

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
		require(partition != DEFAULT_PARTITION, "ERC1400: approveByPartition default partition");
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
		require(partition != DEFAULT_PARTITION, "ERC1400: default partition");
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
		require(partition != DEFAULT_PARTITION, "ERC1400: default partition");
		_approveByPartition(
			partition,
			msg.sender,
			spender,
			_allowanceByPartition[msg.sender][partition][spender] - subtractedValue
		);
		return true;
	}

	/**
	 * @notice authorize an operator to use msg.sender's tokens irrespective of partitions.
	 * @notice this grants permission to the operator to transfer ALL tokens of msg.sender.
	 * @notice this includes burning tokens on behalf of the token holder.
	 * @param operator address to authorize as operator for caller.
	 */
	function authorizeOperator(address operator) public virtual override {
		require(operator != msg.sender, "ERC1400: self authorization not allowed");
		_approvedOperator[msg.sender][operator] = true;
		emit AuthorizedOperator(operator, msg.sender);
	}

	/**
	 * @notice authorize an operator to use msg.sender's tokens of a given partition.
	 * @notice this grants permission to the operator to transfer tokens of msg.sender for a given partition.
	 * @notice this includes burning tokens of @param partition on behalf of the token holder.
	 * @param partition the token partition.
	 * @param operator address to authorize as operator for caller.
	 */
	function authorizeOperatorByPartition(bytes32 partition, address operator) public virtual override {
		require(operator != msg.sender, "ERC1400: self authorization not allowed");
		_approvedOperatorByPartition[msg.sender][partition][operator] = true;
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
		_approvedOperator[msg.sender][operator] = false;
		emit RevokedOperator(operator, msg.sender);
	}

	/**
	 * @notice revoke an operator's rights to use msg.sender's tokens of a given partition.
	 * @notice this will revoke ALL operator rights of the msg.sender for a given partition.
	 * @param partition the token partition.
	 * @param operator address to revoke as operator for caller.
	 */
	function revokeOperatorByPartition(bytes32 partition, address operator) public virtual override {
		_approvedOperatorByPartition[msg.sender][partition][operator] = false;
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
	 * @notice add controllers for the token.
	 */
	function addControllers(address[] calldata controllers) external virtual onlyOwner {
		uint256 controllersLength = controllers.length;
		uint256 i;

		for (; i < controllersLength; ) {
			require(controllers[i] != address(0), "ERC1400: controller is zero address");
			require(
				_controllerIndex[controllers[i]] == 0 && _controllers[0] != controllers[i],
				"ERC1400: already controller"
			);

			uint256 newControllerIndex = _controllers.length;

			_controllers.push(controllers[i]);
			_controllerIndex[controllers[i]] = newControllerIndex;
			emit ControllerAdded(controllers[i]);

			unchecked {
				++i;
			}
		}
	}

	/**
	 * @notice remove controllers for the token.
	 */
	function removeControllers(address[] calldata controllers) external virtual onlyOwner {
		uint256 controllersLength = controllers.length;
		uint256 i;

		for (; i < controllersLength; ) {
			require(controllers[i] != address(0), "ERC1400: controller is zero address");

			uint256 controllerIndex = _controllerIndex[controllers[i]];

			if (controllerIndex == 0 && _controllers[0] != controllers[i]) {
				revert("ERC1400: not controller");
			}

			uint256 lastControllerIndex = _controllers.length - 1;
			address lastController = _controllers[lastControllerIndex];

			_controllers[controllerIndex] = lastController;
			_controllerIndex[lastController] = controllerIndex;
			delete _controllerIndex[controllers[i]];
			_controllers.pop();

			emit ControllerRemoved(controllers[i]);

			unchecked {
				++i;
			}
		}
	}

	// -------------------------------------------------------------------- ISSUANCE -------------------------------------------------------------------- //

	/**
	 /**
	 * @notice allows the owner to issue tokens to an account from the default partition.
	 * @notice since owner is the only one who can issue tokens, no need to validate data as a signature?
	 * @param account the address to issue tokens to.
	 * @param amount the amount of tokens to issue.
	 * @param data additional data attached to the issue.
	 */
	function issue(address account, uint256 amount, bytes calldata data) public virtual override onlyOwner {
		_issue(account, amount, data);
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
		require(partition != DEFAULT_PARTITION, "ERC1400: Invalid partition (DEFAULT_PARTITION)");
		_issueByPartition(partition, account, amount, data);
	}

	// -------------------------------------------------------------------- REDEMPTION -------------------------------------------------------------------- //
	/**
	 * @dev See {IERC1594-redeem}.
	 */
	function redeem(uint256 amount, bytes calldata data) public virtual override {
		_redeem(msg.sender, msg.sender, amount, data, "");
	}

	/**
	 * @dev See {IERC1594-redeemFrom}.
	 */
	function redeemFrom(address tokenHolder, uint256 amount, bytes calldata data) public virtual override onlyOwner {
		_redeem(msg.sender, tokenHolder, amount, data, "");
	}

	/**
	 * @notice allows users to redeem token. Redemptions should be approved by the issuer.
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
	 * @param data and @param operatorData would be "" unless the operator wishes to send additional metadata.
	 */
	function operatorRedeemByPartition(
		bytes32 partition,
		address account,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) public virtual override {
		if (partition == DEFAULT_PARTITION) {
			require(isOperator(msg.sender, account), "ERC1400: Not an operator");
			_redeem(msg.sender, account, amount, data, operatorData);
			return;
		}
		_redeemByPartition(partition, msg.sender, account, amount, data, operatorData);
	}

	/**
	 * @dev See {IERC1644-controllerRedeem}.
	 */
	function controllerRedeem(
		address tokenHolder,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) public virtual override onlyController {
		_redeem(msg.sender, tokenHolder, amount, data, operatorData);

		emit ControllerRedemption(msg.sender, tokenHolder, amount, data, operatorData);
	}

	/**
	 * @dev See {IERC1644-controllerRedeem}.
	 */
	function controllerRedeemByPartition(
		bytes32 partition,
		address tokenHolder,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) public virtual onlyController {
		_redeemByPartition(partition, msg.sender, tokenHolder, amount, data, operatorData);

		emit ControllerRedemptionByPartition(partition, msg.sender, tokenHolder, amount, data, operatorData);
	}

	// --------------------------------------------------------------- INTERNAL FUNCTIONS --------------------------------------------------------------- //
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
		//! Add controller ability to transfer from any partition
		require(partition != bytes32(0), "ERC1400: Invalid partition (DEFAULT_PARTITION)");
		require(_balancesByPartition[from][partition] >= amount, "ERC1400: transfer amount exceeds balance");
		require(to != address(0), "ERC1400: transfer to the zero address");
		if (operator != from) {
			require(
				isOperatorForPartition(partition, operator, from) || isOperator(operator, from),
				"ERC1400: transfer operator is not an operator for partition"
			);
		}
		_beforeTokenTransfer(partition, operator, from, to, amount, data, operatorData);
		_balancesByPartition[from][partition] -= amount;
		_balances[from] -= amount;

		if (!isUserPartition(partition, to)) {
			_partitionIndexOfUser[to][partition] = _partitionsOf[to].length;
			_partitionsOf[to].push(partition);
		}

		_balancesByPartition[to][partition] += amount;
		_balances[to] += amount;
		emit TransferByPartition(partition, operator, from, to, amount, data, operatorData);

		_afterTokenTransfer(partition, operator, from, to, amount, data, operatorData);
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
		require(_balancesByPartition[from][DEFAULT_PARTITION] >= amount, "ERC1400: transfer amount exceeds balance");
		require(to != address(0), "ERC1400: transfer to the zero address");

		_beforeTokenTransfer(DEFAULT_PARTITION, operator, from, to, amount, data, operatorData);
		_balancesByPartition[from][DEFAULT_PARTITION] -= amount;
		_balances[from] -= amount;

		_balancesByPartition[to][DEFAULT_PARTITION] += amount;
		_balances[to] += amount;
		emit Transfer(operator, from, to, amount, DEFAULT_PARTITION, data, operatorData);

		_afterTokenTransfer(DEFAULT_PARTITION, operator, from, to, amount, data, operatorData);
	}

	/**
	 * @dev transfers tokens from a sender to a recipient with data
	 */
	function _transferWithData(
		address operator,
		address from,
		address to,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {
		_beforeTokenTransfer(DEFAULT_PARTITION, operator, from, to, amount, data, operatorData);

		require(_validateData(owner(), from, to, amount, DEFAULT_PARTITION, data), "ERC1400: invalid data");

		_transfer(operator, from, to, amount, data, operatorData);
		emit TransferWithData(msg.sender, to, amount, data);
		_afterTokenTransfer(DEFAULT_PARTITION, operator, from, to, amount, data, operatorData);
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
			require(currentAllowance >= amount, "ERC1400: insufficient allowance");
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
			require(currentAllowance >= amount, "ERC1400: insufficient partition allowance");
			unchecked {
				_approveByPartition(partition, owner, spender, currentAllowance - amount);
			}
		}
	}

	/**
	 * @notice internal function to issue tokens from the default partition.
	 * @param account the address to issue tokens to
	 * @param amount the amount to issue
	 * @param data additional data attached to the issuance
	 */
	function _issue(address account, uint256 amount, bytes memory data) internal virtual {
		require(account != address(0), "ERC1400: Invalid recipient (zero address)");
		require(_isIssuable, "ERC1400: Token is not issuable");
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
	 * @notice internal function to issue tokens from any partition but the default one.
	 * @param account the address to issue tokens to
	 * @param amount the amount to issue
	 * @param data additional data attached to the issuance
	 */
	function _issueByPartition(bytes32 partition, address account, uint256 amount, bytes memory data) internal virtual {
		require(account != address(0), "ERC1400: Invalid recipient (zero address)");
		require(_isIssuable, "ERC1400: Token is not issuable");

		_beforeTokenTransfer(partition, msg.sender, address(0), account, amount, data, "");
		_totalSupply += amount;
		unchecked {
			_totalSupplyByPartition[partition] += amount;
			_balances[account] += amount;
			_balancesByPartition[account][partition] += amount;
		}
		_addTokenToPartitionList(partition, account);

		//emit IssuedByPartition(partition, account, amount, data);
		_afterTokenTransfer(partition, msg.sender, address(0), account, amount, data, "");
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
	 * @dev burns tokens from a recipient
	 */
	function _redeem(
		address operator,
		address account,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {
		_beforeTokenTransfer(DEFAULT_PARTITION, operator, account, address(0), amount, data, operatorData);

		require(_balancesByPartition[account][DEFAULT_PARTITION] >= amount, "ERC1400: Not enough funds");

		_balances[account] -= amount;
		_balancesByPartition[account][DEFAULT_PARTITION] -= amount;
		_totalSupply -= amount;
		_totalSupplyByPartition[DEFAULT_PARTITION] -= amount;
		emit Redeemed(operator, account, amount, data);
		_afterTokenTransfer(DEFAULT_PARTITION, operator, account, address(0), amount, data, operatorData);
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

		require(_balancesByPartition[account][partition] >= amount, "ERC1400: Not enough balance");
		if (operator != account) {
			require(
				isOperatorForPartition(partition, operator, account) || isOperator(operator, account),
				"ERC1400: transfer operator is not an operator for partition"
			);
		}

		_balances[account] -= amount;
		_balancesByPartition[account][partition] -= amount;
		_totalSupply -= amount;
		_totalSupplyByPartition[partition] -= amount;

		emit RedeemedByPartition(partition, operator, account, amount, data, operatorData);
		_afterTokenTransfer(partition, operator, account, address(0), amount, data, operatorData);
	}

	function _validateData(
		address authorizer,
		address from,
		address to,
		uint256 amount,
		bytes32 partition,
		bytes memory signature
	) internal view virtual returns (bool) {
		bytes32 structData = keccak256(
			abi.encodePacked(ERC1400_DATA_VALIDATION_HASH, from, to, amount, partition, _userNonce[authorizer])
		);
		bytes32 structDataHash = _hashTypedDataV4(structData);
		address recoveredSigner = ECDSA.recover(structDataHash, signature);

		return recoveredSigner == authorizer;
	}

	/**
	 * @dev disables issuance of tokens, can only be called by the owner
	 */
	function disableIssuance() public virtual onlyOwner {
		_disableIssuance();
	}

	/**
	 * @dev renounce ownership and disables issuance of tokens
	 */
	function renounceOwnership() public virtual override onlyOwner {
		_disableIssuance();
		super.renounceOwnership();
	}

	/**
	 * @dev intenal function to disable issuance of tokens
	 */
	function _disableIssuance() internal virtual {
		_isIssuable = false;
		emit IssuanceDisabled();
	}

	// --------------------------------------------------------------- HOOKS --------------------------------------------------------------- //

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
