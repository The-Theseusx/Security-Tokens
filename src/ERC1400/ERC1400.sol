//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { Pausable } from "openzeppelin-contracts/contracts/security/Pausable.sol";
import { Context } from "openzeppelin-contracts/contracts/utils/Context.sol";
import { ERC1643 } from "../ERC1643/ERC1643.sol";
import { ERC1400ValidateDataParams } from "../utils/DataTypes.sol";
import { ERC165 } from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import { EIP712 } from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import { IERC1400 } from "./IERC1400.sol";
import { IERC1400Receiver } from "./IERC1400Receiver.sol";
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract ERC1400 is IERC1400, Context, EIP712, ERC165, ERC1643 {
	// --------------------------------------------------------------- CONSTANTS --------------------------------------------------------------- //

	///@dev tokens not belonging to any partition should use this partition
	bytes32 public constant DEFAULT_PARTITION = bytes32(0);

	///@dev EIP712 typehash for data validation
	bytes32 public constant ERC1400_DATA_VALIDATION_TYPEHASH =
		keccak256(
			"ERC1400ValidateData(address from,address to,uint256 amount,bytes32 partition,uint256 nonce,uint48 deadline)"
		);

	///@dev Access control role for the token issuer.
	bytes32 public constant ERC1400_ISSUER_ROLE = keccak256("ERC1400_ISSUER_ROLE");

	///@dev Access control role for the token redeemer.
	bytes32 public constant ERC1400_REDEEMER_ROLE = keccak256("ERC1400_REDEEMER_ROLE");

	///@dev Access control role for the token transfer agent. Transfer agents can authorize transfers with their signatures.
	bytes32 public constant ERC1400_TRANSFER_AGENT_ROLE = keccak256("ERC1400_TRANSFER_AGENT_ROLE");

	// --------------------------------------------------------- PRIVATE STATE VARIABLES --------------------------------------------------------- //

	///@dev should track if token is issuable or not. Should not be modifiable if false.
	bool private _isIssuable;

	///@dev token name
	string private _name;

	///@dev token symbol
	string private _symbol;

	///@dev token contract version for EIP712
	string private _version;

	///@dev token total suppply irrespective of partition.
	uint256 private _totalSupply;

	///@dev mapping of partition to total token supply of partition.
	mapping(bytes32 => uint256) private _totalSupplyByPartition;

	///@dev array of token partitions.
	bytes32[] private _partitions;

	///@dev array of token controllers.
	address[] private _controllers;

	///@dev mapping of partition to index in _partitions array.
	mapping(bytes32 => uint256) private _partitionIndex;

	///@dev mapping of controller to index in _controllers array.
	mapping(address => uint256) private _controllerIndex;

	///@dev mapping from user to array of partitions.
	mapping(address => bytes32[]) private _partitionsOf;

	///@dev mapping of user to mapping of partition in _partitionsOf array to index of partition in this array.
	mapping(address => mapping(bytes32 => uint256)) private _partitionIndexOfUser;

	///@dev mapping from user to total token balances irrespective of partition.
	mapping(address => uint256) private _balances;

	///@dev mapping from user to partition to total token balances of corresponding partition.
	mapping(address => mapping(bytes32 => uint256)) private _balancesByPartition;

	///@dev mapping of user to partition to spender to allowance of token by partition.
	mapping(address => mapping(bytes32 => mapping(address => uint256))) private _allowanceByPartition;

	///@dev mapping of users to partition to operator to approved status of token transfer.
	mapping(address => mapping(bytes32 => mapping(address => bool))) private _approvedOperatorByPartition;

	/**
	 * @dev mapping of users to operator to approved status of token transfer irrespective of partition.
	 * @notice operators can spend tokens on behalf of users irrespective of _allowance as long as this mapping is true.
	 */
	mapping(address => mapping(address => bool)) private _approvedOperator;

	///@dev mapping of used nonces
	mapping(bytes32 => uint256) private _roleNonce;

	// --------------------------------------------------------------- EVENTS --------------------------------------------------------------- //

	///@dev event emitted when tokens are transferred with data attached
	event TransferWithData(
		address indexed authorizer,
		address indexed from,
		address indexed to,
		uint256 amount,
		bytes data
	);
	///@dev event emitted when issuance is disabled
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

	// --------------------------------------------------------------- MODIFIERS --------------------------------------------------------------- //

	modifier onlyController() {
		require(_controllers[_controllerIndex[_msgSender()]] == _msgSender(), "ERC1400: caller is not a controller");
		_;
	}

	modifier isValidPartition(bytes32 partition) {
		require(
			partition == DEFAULT_PARTITION ||
				(_partitions.length != 0 && _partitions[_partitionIndex[partition]] == partition),
			"ERC1400: nonexistent partition"
		);
		_;
	}

	// --------------------------------------------------------------- CONSTRUCTOR --------------------------------------------------------------- //

	constructor(
		string memory name_,
		string memory symbol_,
		string memory version_,
		address tokenAdmin_,
		address tokenIssuer_,
		address tokenRedeemer_,
		address tokenTransferAgent_
	) EIP712(name_, version_) ERC1643(tokenAdmin_) {
		require(bytes(name_).length != 0, "ERC1400: name required");
		require(bytes(symbol_).length != 0, "ERC1400: symbol required");
		require(bytes(version_).length != 0, "ERC1400: version required");
		require(tokenAdmin_ != address(0), "ERC1400: invalid token admin");
		require(tokenIssuer_ != address(0), "ERC1400: invalid token issuer");
		require(tokenRedeemer_ != address(0), "ERC1400: invalid token redeemer");
		require(tokenTransferAgent_ != address(0), "ERC1400: invalid token transfer agent");

		_name = name_;
		_symbol = symbol_;
		_version = version_;
		_isIssuable = true;

		_grantRole(DEFAULT_ADMIN_ROLE, tokenAdmin_);
		_grantRole(ERC1400_ISSUER_ROLE, tokenIssuer_);
		_grantRole(ERC1400_REDEEMER_ROLE, tokenRedeemer_);
		_grantRole(ERC1400_TRANSFER_AGENT_ROLE, tokenTransferAgent_);
	}

	// --------------------------------------------------------------- PUBLIC GETTERS --------------------------------------------------------------- //

	function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, AccessControl) returns (bool) {
		return interfaceId == type(IERC1400).interfaceId || super.supportsInterface(interfaceId);
	}

	/// @return true if more tokens can be issued by the issuer, false otherwise.
	function isIssuable() public view virtual override returns (bool) {
		return _isIssuable;
	}

	/**
	 * @dev Check whether the token is controllable by authorized controllers.
	 * @return bool 'true' if the token is controllable
	 */
	function isControllable() public view virtual override returns (bool) {
		return _controllers.length != 0;
	}

	/// @return the name of the token.
	function name() public view virtual returns (string memory) {
		return _name;
	}

	/// @return the symbol of the token, usually a shorter version of the name.
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

	/// @return the total number of tokens in existence, irrespective of partition.

	function totalSupply() public view virtual override returns (uint256) {
		return _totalSupply;
	}

	/// @return the total number of tokens issued from a given partition, default partition inclusive.
	function totalSupplyByPartition(
		bytes32 partition
	) public view virtual isValidPartition(partition) returns (uint256) {
		return _totalSupplyByPartition[partition];
	}

	/// @return the total number of tokens issued from the default partition.
	function totalSupplyOfNonPartitioned() public view virtual returns (uint256) {
		return _totalSupplyByPartition[DEFAULT_PARTITION];
	}

	/// @return the total number of partitions of this token excluding the default partition.
	function totalPartitions() public view virtual returns (uint256) {
		return _partitions.length;
	}

	/// @return the total token balance of a user irrespective of partition.
	function balanceOf(address account) public view virtual override returns (uint256) {
		return _balances[account];
	}

	/// @return the balance of a user for a given partition, default partition inclusive.
	function balanceOfByPartition(
		bytes32 partition,
		address account
	) public view virtual override isValidPartition(partition) returns (uint256) {
		return _balancesByPartition[account][partition];
	}

	/// @return the total token balance of a user for the default partition.
	function balanceOfNonPartitioned(address account) public view virtual returns (uint256) {
		return _balancesByPartition[account][DEFAULT_PARTITION];
	}

	/// @return the allowance of a spender on the default partition.
	function allowance(address owner, address spender) public view virtual returns (uint256) {
		return _allowanceByPartition[owner][DEFAULT_PARTITION][spender];
	}

	/// @return the allowance of a spender on the partition of the tokenHolder, default partition inclusive.
	function allowanceByPartition(
		bytes32 partition,
		address owner,
		address spender
	) public view virtual isValidPartition(partition) returns (uint256) {
		return _allowanceByPartition[owner][partition][spender];
	}

	/// @return the list of partitions of @param account.
	function partitionsOf(address account) public view virtual override returns (bytes32[] memory) {
		return _partitionsOf[account];
	}

	/**
	 * @param partition the token partition.
	 * @param user the address to check whether it has @param partition in its list of partitions.
	 * @return true if the user is the owner of the partition, false otherwise.
	 */
	function isUserPartition(
		bytes32 partition,
		address user
	) public view virtual isValidPartition(partition) returns (bool) {
		return partition == _partitionsOf[user][_partitionIndexOfUser[user][partition]];
	}

	/// @return true if the operator address is allowed to control all tokens of a tokenHolder irrespective of partition.
	function isOperator(address operator, address account) public view virtual override returns (bool) {
		return _approvedOperator[account][operator];
	}

	/// @return true if the operator address is allowed to control tokens of a partition on behalf of the tokenHolder.
	function isOperatorForPartition(
		bytes32 partition,
		address operator,
		address account
	) public view virtual override isValidPartition(partition) returns (bool) {
		return _approvedOperatorByPartition[account][partition][operator];
	}

	/// @return true if @param controller is a controller of this token.
	function isController(address controller) public view virtual returns (bool) {
		return controller == _controllers[_controllerIndex[controller]];
	}

	/// @return the list of controllers of this token.
	function getControllers() public view virtual returns (address[] memory) {
		return _controllers;
	}

	/// @return the nonce of a role.
	function getRoleNonce(bytes32 role) public view virtual returns (uint256) {
		return _roleNonce[role];
	}

	/**
	* @notice Error messages:
	  -IP: Invalid partition
	  -IS: Invalid sender
	  -IPB: Insufficient partition balance
	  -IR: Receiver is invalid
	  -ID: Invalid transfer data
	  -IA: Insufficient allowance
	  -ITA: Insufficient transfer amount

	 * @param from token holder.
	 * @param to token recipient.
	 * @param partition token partition.
	 * @param amount token amount.
	 * @param data information attached to the transfer.
	 */
	function canTransferByPartition(
		address from,
		address to,
		bytes32 partition,
		uint256 amount,
		bytes memory data
	) public view virtual override returns (bytes memory, bytes32, bytes32) {
		uint256 index = _partitionIndex[partition];
		address operator = _msgSender();
		if (_partitions[index] != partition) return ("0x50", "ERC1400: IP", bytes32(0));
		if (balanceOfByPartition(partition, from) < amount) return ("0x52", "ERC1400: IPB", bytes32(0));
		if (from == address(0)) return ("0x56", "ERC1400: IS", bytes32(0));
		if (to == address(0)) return ("0x57", "ERC1400: IR", bytes32(0));
		if (to.code.length != 0) {
			(bool can, ) = _canReceive(partition, operator, from, to, amount, data, "");
			if (!can) return ("0x57", "ERC1400: IR", bytes32(0));
		}
		if (amount == 0) return ("0x50", "ERC1400: ITA", bytes32(0));
		if (amount > allowance(from, operator)) {
			/** @dev possibly called by an operator or controller, check if the sender is an operator or controller */
			if (
				!isOperator(operator, from) ||
				!isOperatorForPartition(partition, operator, from) ||
				!isController(operator)
			) {
				return ("0x53", "IA", bytes32(0));
			}
		}
		if (data.length != 0) {
			ERC1400ValidateDataParams memory _data = ERC1400ValidateDataParams({
				authorizerRole: ERC1400_TRANSFER_AGENT_ROLE,
				from: from,
				to: to,
				amount: amount,
				partition: partition,
				data: data
			});
			(bool can, ) = _validateData(_data);
			if (!can) return ("0x5f", "ERC1400: ID", bytes32(0));
		}

		return ("0x51", "ERC1400: CT", bytes32(0));
	}

	/**
	 * @notice Check if a transfer of tokens associated with the default partition is possible.
	 * @param to token recipient.
	 * @param amount token amount.
	 * @param data information attached to the transfer, by the token holder.
	 */
	function canTransfer(
		address to,
		uint256 amount,
		bytes memory data
	) public view virtual override returns (bool, bytes memory, bytes32) {
		address operator = _msgSender();
		if (to == address(0)) return (false, bytes("0x57"), bytes32(0));
		if (amount == 0) return (false, bytes("0x50"), bytes32(0));
		if (balanceOfNonPartitioned(operator) < amount) return (false, bytes("0x52"), bytes32(0));
		if (to.code.length > 0) {
			(bool can, ) = _canReceive(DEFAULT_PARTITION, operator, operator, to, amount, data, "");
			if (!can) return (false, bytes("0x57"), bytes32(0));
		}

		return (true, bytes("0x51"), bytes32(0));
	}

	/**
	 * @notice Check if a transfer from of tokens of the default partition is possible.
	 * @param from token holder.
	 * @param to token recipient.
	 * @param amount token amount.
	 * @param data information attached to the transfer.
	 */
	function canTransferFrom(
		address from,
		address to,
		uint256 amount,
		bytes memory data
	) public view virtual override returns (bool, bytes memory, bytes32) {
		address operator = _msgSender();
		if (from == address(0)) return (false, bytes("0x56"), bytes32(0));
		if (to == address(0)) return (false, bytes("0x57"), bytes32(0));
		if (to.code.length > 0) {
			(bool can, ) = _canReceive(DEFAULT_PARTITION, operator, from, to, amount, data, "");
			if (!can) return (false, bytes("0x57"), bytes32(0));
		}
		if (amount == 0) return (false, bytes("0x50"), bytes32(0));
		if (amount > allowance(from, operator)) {
			/** @dev possibly called by an operator or controller, check if the sender is an operator or controller */
			if (
				!isOperator(operator, from) ||
				!isOperatorForPartition(DEFAULT_PARTITION, operator, from) ||
				!isController(operator)
			) {
				return (false, bytes("0x53"), bytes32(0));
			}
		}
		if (balanceOfNonPartitioned(operator) < amount) return (false, bytes("0x52"), bytes32(0));
		if (data.length != 0) {
			ERC1400ValidateDataParams memory _data = ERC1400ValidateDataParams({
				authorizerRole: ERC1400_TRANSFER_AGENT_ROLE,
				from: from,
				to: to,
				amount: amount,
				partition: DEFAULT_PARTITION,
				data: data
			});
			(bool can, ) = _validateData(_data);
			if (!can) return (false, bytes("0x5f"), bytes32(0));
		}
		return (true, bytes("0x51"), bytes32(0));
	}

	/**
	 * @notice considering the different return data formats of 
	 * IERC1594 canTransfer, IERC1594 canTransferFrom and IERC1410 canTransferByPartition, 
	 * this method tries to combine all into one canTransfer function.
	 
	 * @param partition the partition to execute the transfer on.
	 * @param from the address to transfer from
	 * @param to the address to transfer to
	 * @param amount the amount of tokens to transfer
	 * @param data transfer data.
	 * @param validateData if true, will validate the data as a signature authorizing the transfer.
	 * @param data the data to validate as a signature authorizing the transfer or extra metadata to go with the transfer.
	 * @return bool if the transfer is possible with no error message else false with the error message.
	 */
	function canTransfer(
		bytes32 partition,
		address from,
		address to,
		uint256 amount,
		bool validateData,
		bytes memory data
	) public view virtual returns (bool, string memory) {
		bytes memory message;

		if (partition == DEFAULT_PARTITION) {
			if (from == to) {
				(bool can, bytes memory returnedMessage, ) = canTransfer(to, amount, data);
				if (can) return (true, "");
				message = returnedMessage;
			} else {
				(bool can, bytes memory returnedMessage, ) = canTransferFrom(from, to, amount, data);
				if (can) return (true, "");
				message = returnedMessage;
			}
		} else {
			(bytes memory returnedMessage, , ) = canTransferByPartition(from, to, partition, amount, data);
			if (keccak256(returnedMessage) == keccak256("0x51")) return (true, "");
			message = returnedMessage;
		}

		if (keccak256(message) == keccak256("0x50")) {
			return (false, "ERC1400: Invalid amount, partition or transfer failure");
		}
		if (keccak256(message) == keccak256("0x52")) return (false, "ERC1400: Insufficient balance");
		if (keccak256(message) == keccak256("0x53")) return (false, "ERC1400: insufficient allowance");
		if (keccak256(message) == keccak256("0x56")) return (false, "ERC1400: Invalid sender");
		if (keccak256(message) == keccak256("0x57")) return (false, "ERC1400: Cannot receive");
		if (keccak256(message) == keccak256("0x5f")) {
			return validateData ? (false, "ERC1400: Invalid transfer data") : (true, "");
		}

		return (false, "ERC1400: Failed with unknown error");
	}

	// --------------------------------------------------------------- TRANSFERS --------------------------------------------------------------- //

	/**
	 * @notice transfers tokens associated to the default partition, see transferByPartition to transfer from the non-default partition.
	 * @param to the address to transfer tokens to
	 * @param amount the amount to transfer from
	 * @return true if successful
	 */
	function transfer(address to, uint256 amount) public virtual returns (bool) {
		address operator = _msgSender();
		_transfer(operator, operator, to, amount, "", "");
		return true;
	}

	/**
	 * @notice transfer tokens from the default partition with additional data.
	 * @param to the address to transfer tokens to
	 * @param amount the amount to transfer
	 * @param data transfer data.
	 */
	function transferWithData(address to, uint256 amount, bytes memory data) public virtual override {
		require(data.length != 0, "ERC1400: Invalid data");
		address operator = _msgSender();
		_transferWithData(operator, operator, to, amount, data, "");
	}

	/**
	 * @notice since msg.sender is the token holder, the data argument would be empty ("") unless the token holder wishes to send additional metadata.
	 * @param partition the token partition to transfer
	 * @param to the address to transfer to
	 * @param amount the amount to transfer
	 * @param data transfer data.
	 * @return partition if successful
	 */
	function transferByPartition(
		bytes32 partition,
		address to,
		uint256 amount,
		bytes memory data
	) public virtual override isValidPartition(partition) returns (bytes32) {
		address operator = _msgSender();
		_transferByPartition(partition, operator, operator, to, amount, data, "");
		return partition;
	}

	/**
	 * @param partition the partition the token to transfer is associated with
	 * @param from the address to transfer from
	 * @param to the address to transfer to
	 * @param amount the amount to transfer
	 * @param data transfer data.
	 * @param operatorData additional data attached by the operator (if any)
	 * @notice since msg.sender is supposed to be an authorized operator,
	   @param data and @param operatorData would be "" unless the operator wishes to send additional metadata.
	 */
	function operatorTransferByPartition(
		bytes32 partition,
		address from,
		address to,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) public virtual override isValidPartition(partition) returns (bytes32) {
		address operator = _msgSender();

		require(
			isOperator(operator, from) || isOperatorForPartition(partition, operator, from),
			"ERC1400: Not authorized operator"
		);
		_transferByPartition(partition, operator, from, to, amount, data, operatorData);
		return partition;
	}

	/**
	 * @notice for controllers to transfer tokens associated with the default partition.
	 * @param from the address to transfer from
	 * @param to the address to transfer to
	 * @param amount the amount to transfer
	 * @param data additional transfer data.
	 * @param operatorData additional data attached by the operator (if any)
	 */
	function controllerTransfer(
		address from,
		address to,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) public virtual override onlyController {
		address operator = _msgSender();
		_transfer(operator, from, to, amount, data, operatorData);

		emit ControllerTransfer(operator, from, to, amount, data, operatorData);
	}

	/**
	 * @notice for controllers to transfer tokens of any given partition but the default partition.
	 * @param partition the token partition to transfer
	 * @param from the address to transfer from
	 * @param to the address to transfer to
	 * @param amount the amount to transfer
	 * @param data additional transfer data.
	 * @param operatorData additional data attached by the operator (if any)
	 */
	function controllerTransferByPartition(
		bytes32 partition,
		address from,
		address to,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) public virtual onlyController isValidPartition(partition) {
		address operator = _msgSender();
		_transferByPartition(partition, operator, from, to, amount, data, operatorData);

		emit ControllerTransferByPartition(partition, operator, from, to, amount, data, operatorData);
	}

	/**
	 * @param from the address to transfer tokens from
	 * @param to the address to transfer tokens to
	 * @param amount the amount to transfer from
	 * @notice transfers from the default partition, see transferFromByPartition to 'transferFrom' a non-default partition.
	 * @return true if successful
	 */
	function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
		address operator = _msgSender();
		_spendAllowance(from, operator, amount);
		_transfer(operator, from, to, amount, "", "");
		return true;
	}

	/**
	 * @notice transfers from the default partition with data.
	 * @param from the address to transfer from
	 * @param to the address to transfer to
	 * @param amount the amount to transfer from
	 * @param data transfer data to be validated.
	 */
	function transferFromWithData(address from, address to, uint256 amount, bytes memory data) public virtual override {
		require(data.length != 0, "ERC1400: Invalid data");
		_transferWithData(_msgSender(), from, to, amount, data, "");
	}

	/**
	 * @notice if an authorized body might be forcing a token transfer from @param from, 
	   the @param data should be a signature authorizing the transfer.
	 * @notice if it is a normal transferFrom, the data should be empty ("").
	 * @param partition the token partition to transfer
	 * @param from the address to transfer from
	 * @param to the address to transfer to
	 * @param amount the amount to transfer
	 * @param data transfer data.
	 * @return partition if successful
	 */
	function transferFromByPartition(
		bytes32 partition,
		address from,
		address to,
		uint256 amount,
		bytes memory data
	) public virtual isValidPartition(partition) returns (bytes32) {
		address operator = _msgSender();
		if (data.length != 0) {
			ERC1400ValidateDataParams memory _data = ERC1400ValidateDataParams({
				authorizerRole: ERC1400_TRANSFER_AGENT_ROLE,
				from: from,
				to: to,
				amount: amount,
				partition: partition,
				data: data
			});
			(bool authorized, address authorizer) = _validateData(_data);
			require(authorized, "ERC1400: Invalid data");
			_spendNonce(ERC1400_TRANSFER_AGENT_ROLE, authorizer);
			_transferByPartition(partition, operator, from, to, amount, data, "");
			return partition;
		}
		_spendAllowanceByPartition(partition, from, operator, amount);
		_transferByPartition(partition, operator, from, to, amount, data, "");
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
		_approve(_msgSender(), spender, amount);
		return true;
	}

	/**
	 * @notice increase the amount of tokens that an owner has approved for a spender to transfer from the default partition.
	 * @param spender the address to approve
	 * @param addedValue the amount to increase the approval by
	 * @return true if successful
	 */
	function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
		address operator = _msgSender();
		_approve(operator, spender, _allowanceByPartition[operator][DEFAULT_PARTITION][spender] + addedValue);
		return true;
	}

	/**
	 * @notice decrease the amount of tokens that an owner has approved for a spender to transfer from the default partition.
	 * @param spender the address to approve
	 * @param subtractedValue the amount to decrease the approval by
	 * @return true if successful
	 */
	function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
		address operator = _msgSender();

		_approve(operator, spender, _allowanceByPartition[operator][DEFAULT_PARTITION][spender] - subtractedValue);
		return true;
	}

	/**
	 * @notice approve a spender to transfer tokens from any partition but the default one.
	 * @param partition the partition to approve
	 * @param spender the address to approve
	 * @param amount the amount to approve
	 * @return true if successful
	 */
	function approveByPartition(
		bytes32 partition,
		address spender,
		uint256 amount
	) public virtual isValidPartition(partition) returns (bool) {
		require(partition != DEFAULT_PARTITION, "ERC1400: default partition");
		_approveByPartition(partition, _msgSender(), spender, amount);
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
	) public virtual isValidPartition(partition) returns (bool) {
		require(partition != DEFAULT_PARTITION, "ERC1400: default partition");
		address operator = _msgSender();

		_approveByPartition(
			partition,
			operator,
			spender,
			_allowanceByPartition[operator][partition][spender] + addedValue
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
	) public virtual isValidPartition(partition) returns (bool) {
		require(partition != DEFAULT_PARTITION, "ERC1400: default partition");
		address operator = _msgSender();

		_approveByPartition(
			partition,
			operator,
			spender,
			_allowanceByPartition[operator][partition][spender] - subtractedValue
		);
		return true;
	}

	/**
	 * @notice authorize an operator to use msg.sender's tokens irrespective of partitions.
	   This includes burning tokens on behalf of the token holder.
	 * @param operator address to authorize as operator for caller.
	 */
	function authorizeOperator(address operator) public virtual override {
		address initiator = _msgSender();
		require(operator != initiator, "ERC1400: self authorization not allowed");
		_approvedOperator[initiator][operator] = true;
		emit AuthorizedOperator(operator, initiator);
	}

	/**
	 * @notice authorize an operator to use msg.sender's tokens of a given partition only. 
	   Not necessary if authorizeOperator has already been called.
	   This includes burning tokens of @param partition on behalf of the token holder.
	 * @param partition the token partition.
	 * @param operator address to authorize as operator for caller.
	 */
	function authorizeOperatorByPartition(
		bytes32 partition,
		address operator
	) public virtual override isValidPartition(partition) {
		address initiator = _msgSender();
		require(operator != initiator, "ERC1400: self authorization not allowed");
		_approvedOperatorByPartition[initiator][partition][operator] = true;
		emit AuthorizedOperatorByPartition(partition, operator, initiator);
	}

	/**
	 * @notice revoke an operator's rights to use msg.sender's tokens.
	 * @notice This will revoke operator rights of @param operator on msg.sender's tokens however,
	   if @param operator has been authorized to use msg.sender's tokens of a given partition, this won't revoke that right.
	   See 'revokeOperatorByPartition' to revoke partition specific rights only or 'revokeOperators' to revoke all rights of an operator.
	 * @param operator address to revoke as operator for caller.
	 */
	function revokeOperator(address operator) public virtual override {
		address initiator = _msgSender();
		_approvedOperator[initiator][operator] = false;
		emit RevokedOperator(operator, initiator);
	}

	/**
	 * @notice revoke an operator's rights to use msg.sender's tokens of a given partition.
	 * @notice this will revoke ALL operator rights of the msg.sender for a given partition.
	 * @param partition the token partition.
	 * @param operator address to revoke as operator for caller.
	 */
	function revokeOperatorByPartition(
		bytes32 partition,
		address operator
	) public virtual override isValidPartition(partition) {
		address initiator = _msgSender();
		_approvedOperatorByPartition[initiator][partition][operator] = false;
		emit RevokedOperatorByPartition(partition, operator, initiator);
	}

	/**
	 * @notice allows a user to revoke all the rights of their operators in a single transaction.
	 * @notice this will revoke ALL operator rights for ALL partitions of msg.sender.
	 * @param operators addresses to revoke as operators for caller.
	 */
	function revokeOperators(address[] memory operators) public virtual {
		address operator = _msgSender();

		bytes32[] memory partitions = partitionsOf(operator);
		uint256 userPartitionCount = partitions.length;
		uint256 operatorCount = operators.length;
		uint256 i;
		uint256 j;
		for (; i < userPartitionCount; ) {
			for (; j < operatorCount; ) {
				if (isOperatorForPartition(partitions[i], operators[j], operator)) {
					revokeOperatorByPartition(partitions[i], operators[j]);
				}

				if (isOperator(operators[j], operator)) {
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
	function addControllers(address[] memory controllers) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
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
	function removeControllers(address[] memory controllers) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
		uint256 controllersLength = controllers.length;
		uint256 i;

		for (; i < controllersLength; ) {
			require(controllers[i] != address(0), "ERC1400: controller is zero address");

			uint256 controllerIndex = _controllerIndex[controllers[i]];

			require(controllerIndex != 0 || _controllers[0] == controllers[i], "ERC1400: not controller");

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

	/**
	 * @dev disables issuance of tokens, can only be called by the owner
	 */
	function disableIssuance() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
		_disableIssuance();
	}

	// -------------------------------------------------------------------- ISSUANCE -------------------------------------------------------------------- //

	/**
	 * @notice allows an authority to issue tokens to an account from the default partition.
	 * @param account the address to issue tokens to.
	 * @param amount the amount of tokens to issue.
	 * @param data additional data attached to the issuance.
	 */
	function issue(
		address account,
		uint256 amount,
		bytes memory data
	) public virtual override onlyRole(ERC1400_ISSUER_ROLE) {
		_issue(_msgSender(), account, amount, data);
	}

	/**
	 * @notice allows an authority to issue tokens to an account from a specific partition other than the default partition.
	 * @param partition the partition to issue tokens from.
	 * @param account the address to issue tokens to.
	 * @param amount the amount of tokens to issue.
	 * @param data additional data attached to the issuance.
	 */
	function issueByPartition(
		bytes32 partition,
		address account,
		uint256 amount,
		bytes memory data
	) public virtual override onlyRole(ERC1400_ISSUER_ROLE) {
		_issueByPartition(partition, _msgSender(), account, amount, data);
	}

	// -------------------------------------------------------------------- REDEMPTION -------------------------------------------------------------------- //

	/**
	 * @notice allows users to redeem token. Securities redemption need to be authorized by the issuer or relevant authority.
	 * @param amount the amount of tokens to redeem.
	 * @param data validation data attached to the redemption process.
	 */
	function redeem(uint256 amount, bytes memory data) public virtual override {
		address operator = _msgSender();
		ERC1400ValidateDataParams memory _data = ERC1400ValidateDataParams({
			authorizerRole: ERC1400_REDEEMER_ROLE,
			from: operator,
			to: address(0),
			amount: amount,
			partition: DEFAULT_PARTITION,
			data: data
		});
		(bool authorized, address authorizer) = _validateData(_data);
		require(authorized, "ERC1400: Invalid data");
		_spendNonce(ERC1400_REDEEMER_ROLE, authorizer);

		_redeem(operator, operator, amount, data, "");
	}

	/**
	 * @notice allows an authority with the right to redeem tokens to redeem tokens on behalf of a token holder.
	 * @param tokenHolder the address to redeem token from.
	 * @param amount the amount of tokens to redeem.
	 * @param data additional data attached to the transfer.
	 */
	function redeemFrom(
		address tokenHolder,
		uint256 amount,
		bytes memory data
	) public virtual override onlyRole(ERC1400_REDEEMER_ROLE) {
		_redeem(_msgSender(), tokenHolder, amount, data, "");
	}

	/**
	 * @notice allows users to redeem token.
	 * @param partition the token partition to reddem from.
	 * @param amount the amount of tokens to redeem.
	 * @param data additional data attached to the transfer.
	 */
	function redeemByPartition(
		bytes32 partition,
		uint256 amount,
		bytes memory data
	) public virtual override isValidPartition(partition) {
		address operator = _msgSender();
		ERC1400ValidateDataParams memory _data = ERC1400ValidateDataParams({
			authorizerRole: ERC1400_REDEEMER_ROLE,
			from: operator,
			to: address(0),
			amount: amount,
			partition: partition,
			data: data
		});
		(bool can, address authorizer) = _validateData(_data);
		require(can, "ERC1400: Invalid data");
		_spendNonce(ERC1400_REDEEMER_ROLE, authorizer);

		_redeemByPartition(partition, operator, operator, amount, data, "");
	}

	/**
	 * @param partition the token partition to redeem, this could be the default partition.
	 * @param account the address to redeem from
	 * @param amount the amount to redeem
	 * @param data redemption validation data.
	 * @param operatorData additional data attached by the operator (if any)
	 */
	function operatorRedeemByPartition(
		bytes32 partition,
		address account,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) public virtual override isValidPartition(partition) {
		address operator = _msgSender();
		require(
			isOperator(operator, account) || isOperatorForPartition(partition, operator, account),
			"ERC1400: Not authorized operator"
		);

		if (partition == DEFAULT_PARTITION) {
			ERC1400ValidateDataParams memory _data = ERC1400ValidateDataParams({
				authorizerRole: ERC1400_REDEEMER_ROLE,
				from: account,
				to: address(0),
				amount: amount,
				partition: partition,
				data: data
			});
			(bool authorized, address authorizer) = _validateData(_data);
			require(authorized, "ERC1400: Invalid data");
			_spendNonce(ERC1400_REDEEMER_ROLE, authorizer);
			_redeem(operator, account, amount, data, operatorData);
			return;
		}
		redeemByPartition(partition, amount, data);
	}

	/**
	 * @notice allows controllers to redeem tokens of the default partition of users.
	 * @param tokenHolder the address to redeem token from.
	 * @param amount the amount of tokens to redeem.
	 * @param data additional data attached to the transfer.
	 * @param operatorData additional data attached by the operator (if any)
	 */
	function controllerRedeem(
		address tokenHolder,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) public virtual override onlyController {
		address operator = _msgSender();

		_redeem(operator, tokenHolder, amount, data, operatorData);

		emit ControllerRedemption(operator, tokenHolder, amount, data, operatorData);
	}

	/**
	 * @notice allows controllers to redeem tokens of a given partition of users.
	 * @param partition the token partition to redeem.
	 * @param tokenHolder the address to redeem token from.
	 * @param amount the amount of tokens to redeem.
	 * @param data additional data attached to the transfer.
	 * @param operatorData additional data attached by the operator (if any)
	 */
	function controllerRedeemByPartition(
		bytes32 partition,
		address tokenHolder,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) public virtual onlyController isValidPartition(partition) {
		address operator = _msgSender();

		_redeemByPartition(partition, operator, tokenHolder, amount, data, operatorData);

		emit ControllerRedemptionByPartition(partition, operator, tokenHolder, amount, data, operatorData);
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
		require(partition != DEFAULT_PARTITION, "ERC1400: Wrong partition (DEFAULT_PARTITION)");
		require(_balancesByPartition[from][partition] >= amount, "ERC1400: transfer amount exceeds balance");
		require(to != address(0), "ERC1400: transfer to the zero address");
		if (operator != from) {
			require(
				isOperatorForPartition(partition, operator, from) ||
					isOperator(operator, from) ||
					isController(operator),
				"ERC1400: not an operator or controller for partition"
			);
		}
		/** @dev prevent zero token transfers (spam transfers) */
		require(amount != 0, "ERC1400: zero amount");
		_beforeTokenTransfer(partition, operator, from, to, amount, data, operatorData);
		require(
			_checkOnERC1400Received(partition, operator, from, to, amount, data, operatorData),
			"ERC1400: transfer to non ERC1400Receiver implementer"
		);

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
		/** @dev prevent zero token transfers (spam transfers) */
		require(amount != 0, "ERC1400: zero amount");

		_beforeTokenTransfer(DEFAULT_PARTITION, operator, from, to, amount, data, operatorData);
		require(
			_checkOnERC1400Received(DEFAULT_PARTITION, operator, from, to, amount, data, operatorData),
			"ERC1400: transfer to non ERC1400Receiver implementer"
		);

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
		ERC1400ValidateDataParams memory _data = ERC1400ValidateDataParams({
			authorizerRole: ERC1400_TRANSFER_AGENT_ROLE,
			from: from,
			to: to,
			amount: amount,
			partition: DEFAULT_PARTITION,
			data: data
		});

		(bool authorized, address authorizer) = _validateData(_data);
		require(authorized, "ERC1400: invalid data");
		_spendNonce(ERC1400_TRANSFER_AGENT_ROLE, authorizer);

		_transfer(operator, from, to, amount, data, operatorData);
		emit TransferWithData(authorizer, operator, to, amount, data);
		_afterTokenTransfer(DEFAULT_PARTITION, operator, from, to, amount, data, operatorData);
	}

	/**
	 * @notice change the partition of tokens belonging to a given address
	 * @param partitionFrom the current partition of the tokens
	 * @param partitionTo the partition to change tokens to
	 * @param operator the address performing the change
	 * @param account the address holding the tokens
	 * @param amount the amount of tokens to change
	 * @param data additional data attached to the change
	 * @param operatorData additional data attached to the change by the operator (if any)
	 */
	function _changePartition(
		bytes32 partitionFrom,
		bytes32 partitionTo,
		address operator,
		address account,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) internal virtual isValidPartition(partitionFrom) isValidPartition(partitionTo) {
		if (operator != account) {
			require(
				isOperatorForPartition(partitionFrom, operator, account) ||
					isOperator(operator, account) ||
					isController(operator),
				"ERC1400: not operator or controller for partition"
			);
		}
		require(_balancesByPartition[account][partitionFrom] >= amount, "ERC1400: insufficient balance");

		_balancesByPartition[account][partitionFrom] -= amount;
		_totalSupplyByPartition[partitionFrom] -= amount;
		_balancesByPartition[account][partitionTo] += amount;
		_totalSupplyByPartition[partitionTo] += amount;

		emit ChangedPartition(operator, partitionFrom, partitionTo, account, amount, data, operatorData);
	}

	/**
	 * @notice internal approve function for default partition
	 * @param owner the address that holds the tokens to be spent
	 * @param spender the address that will spend the tokens
	 * @param amount the amount of tokens to be spent
	 */
	function _approve(address owner, address spender, uint256 amount) internal virtual {
		_approveByPartition(DEFAULT_PARTITION, owner, spender, amount);
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
			_approve(owner, spender, currentAllowance - amount);
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
			_approveByPartition(partition, owner, spender, currentAllowance - amount);
		}
	}

	/**
	 * @notice internal function to issue tokens from the default partition.
	 * @param operator the address performing the issuance
	 * @param account the address to issue tokens to
	 * @param amount the amount to issue
	 * @param data additional data attached to the issuance
	 */
	function _issue(address operator, address account, uint256 amount, bytes memory data) internal virtual {
		require(account != address(0), "ERC1400: Invalid recipient (zero address)");
		require(_isIssuable, "ERC1400: Token is not issuable");
		require(amount != 0, "ERC1400: zero amount");

		_beforeTokenTransfer(DEFAULT_PARTITION, operator, address(0), account, amount, data, "");
		require(
			_checkOnERC1400Received(DEFAULT_PARTITION, operator, address(0), account, amount, data, ""),
			"ERC1400: transfer to non ERC1400Receiver implementer"
		);

		_totalSupply += amount;
		_balances[account] += amount;
		_balancesByPartition[account][DEFAULT_PARTITION] += amount;
		_totalSupplyByPartition[DEFAULT_PARTITION] += amount;

		emit Issued(operator, account, amount, data);
		_afterTokenTransfer(DEFAULT_PARTITION, operator, address(0), account, amount, data, "");
	}

	/**
	 * @notice internal function to issue tokens from any partition but the default one.
	 * @param partition the partition to issue tokens from
	 * @param operator the address performing the issuance
	 * @param account the address to issue tokens to
	 * @param amount the amount to issue
	 * @param data additional data attached to the issuance
	 */
	function _issueByPartition(
		bytes32 partition,
		address operator,
		address account,
		uint256 amount,
		bytes memory data
	) internal virtual {
		require(account != address(0), "ERC1400: Invalid recipient (zero address)");
		require(_isIssuable, "ERC1400: Token is not issuable");
		require(partition != DEFAULT_PARTITION, "ERC1400: Invalid partition (default)");
		require(amount != 0, "ERC1400: zero amount");

		_beforeTokenTransfer(partition, operator, address(0), account, amount, data, "");
		require(
			_checkOnERC1400Received(partition, operator, address(0), account, amount, data, ""),
			"ERC1400: transfer to non ERC1400Receiver implementer"
		);

		_totalSupply += amount;
		_totalSupplyByPartition[partition] += amount;
		_balances[account] += amount;
		_balancesByPartition[account][partition] += amount;

		_addTokenToPartitionList(partition, account);

		emit IssuedByPartition(partition, account, amount, data);
		_afterTokenTransfer(partition, operator, address(0), account, amount, data, "");
	}

	/**
	 * @notice internal function to update the contract token partition lists.
	 */
	function _addTokenToPartitionList(bytes32 partition, address account) internal virtual {
		bytes32[] memory partitions = _partitions;
		uint256 index = _partitionIndex[partition];

		bytes32 currentPartition = partitions[index];

		if (partition != currentPartition) {
			///@dev partition does not exist, add partition to contract

			_partitionIndex[partition] = partitions.length;
			_partitions.push(partition);

			///@dev add partition to user's partition list
			_partitionIndexOfUser[account][partition] = _partitionsOf[account].length;
			_partitionsOf[account].push(partition);
		} else {
			///@dev partition exists, add partition to user's partition list if not already added
			if (!isUserPartition(partition, account)) {
				_partitionIndexOfUser[account][partition] = _partitionsOf[account].length;
				_partitionsOf[account].push(partition);
			}
		}
	}

	/**
	 * @notice burns tokens from a recipient's default partition.
	 * @param operator the address performing the redeem
	 * @param account the address to redeem tokens from
	 * @param amount the amount to redeem
	 * @param data additional data attached to the redeem process
	 * @param operatorData additional data attached to the redeem process by the operator (if any)
	 */
	function _redeem(
		address operator,
		address account,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {
		_beforeTokenTransfer(DEFAULT_PARTITION, operator, account, address(0), amount, data, operatorData);
		if (operator != account) {
			require(
				isOperator(operator, account) ||
					isOperatorForPartition(DEFAULT_PARTITION, operator, account) ||
					isController(operator),
				"ERC1400: transfer operator is not authorized"
			);
		}
		require(amount != 0, "ERC1400: zero amount");
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
		require(partition != DEFAULT_PARTITION, "ERC1400: Wrong partition (DEFAULT_PARTITION)");
		require(_balancesByPartition[account][partition] >= amount, "ERC1400: Insufficient balance");
		require(amount != 0, "ERC1400: zero amount");
		if (operator != account) {
			require(
				isOperatorForPartition(partition, operator, account) ||
					isOperator(operator, account) ||
					isController(operator),
				"ERC1400: transfer operator is not authorized"
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
	 * @notice validate the data provided by the user when performing transactions that require validated data (signatures)
	 * @notice reverts if the data is not encoded with the signature and dealine
	 * @param validateDataParams struct params containing data to be validated
	 * @return bool 'true' if the recovered signer has @param authorizerRole, 'false' if not
	 * @return the recovered signer
	 */
	function _validateData(
		ERC1400ValidateDataParams memory validateDataParams
	) internal view virtual returns (bool, address) {
		(bytes memory signature, uint48 deadline) = abi.decode(validateDataParams.data, (bytes, uint48));
		require(deadline >= block.timestamp, "ERC1400: Expired signature");

		bytes32 structData = keccak256(
			abi.encodePacked(
				ERC1400_DATA_VALIDATION_TYPEHASH,
				validateDataParams.from,
				validateDataParams.to,
				validateDataParams.amount,
				validateDataParams.partition,
				_roleNonce[validateDataParams.authorizerRole],
				deadline
			)
		);
		bytes32 structDataHash = _hashTypedDataV4(structData);
		address recoveredSigner = ECDSA.recover(structDataHash, signature);
		return (hasRole(validateDataParams.authorizerRole, recoveredSigner), recoveredSigner);
	}

	/**
	 * @notice increase the nonce of a role usually after a transaction signature has been validated.
	 * This function MUST be called whenever a signature is validated for a given role to prevent replay attacks.
	 * Methods such as canTransfer and it's variants, may validate a signature before the actual transaction occurs. 
	 * In such a case, this function SHOULD NOT be called as the state-changing transaction has not been performed yet.
	 
	 * @param role the role for which the nonce is increased
	 * @param spender the address that spent the nonce in a signature
	 */
	function _spendNonce(bytes32 role, address spender) private {
		uint256 nonce = ++_roleNonce[role];
		emit NonceSpent(role, spender, nonce - 1);
	}

	/// @dev intenal function to disable issuance of tokens
	function _disableIssuance() internal virtual {
		_isIssuable = false;
		emit IssuanceDisabled();
	}

	/**
	 * @notice checks if @param to can receive ERC1400 tokens.
	 * @param partition the partition to transfer tokens from
	 * @param operator the address performing the transfer
	 * @param from the address to transfer tokens from
	 * @param to the address to transfer tokens to, should be a contract
	 * @param amount the amount to transfer
	 * @param data additional data attached to the transfer
	 * @param operatorData additional data attached to the transfer by the operator (if any)
	 * @return bool 'true' if @param to can receive ERC1400 tokens, 'false' if not with corresponding revert data.
	 */
	function _canReceive(
		bytes32 partition,
		address operator,
		address from,
		address to,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) internal view virtual returns (bool, bytes memory) {
		try IERC1400Receiver(to).onERC1400Received(partition, operator, from, to, amount, data, operatorData) returns (
			bytes4 retVal
		) {
			return (retVal == IERC1400Receiver.onERC1400Received.selector, "");
		} catch (bytes memory reason) {
			return (false, reason);
		}
	}

	// --------------------------------------------------------------- HOOKS --------------------------------------------------------------- //

	/**
	 * @notice hook to be called to check if @param to can receive ERC1400 tokens. Reverts if not.
	 * @param partition the partition to transfer tokens from
	 * @param operator the address performing the transfer
	 * @param from the address to transfer tokens from
	 * @param to the address to transfer tokens to
	 * @param amount the amount to transfer
	 * @param data additional data attached to the transfer
	 * @param operatorData additional data attached to the transfer by the operator (if any)
	 */
	function _checkOnERC1400Received(
		bytes32 partition,
		address operator,
		address from,
		address to,
		uint256 amount,
		bytes memory data,
		bytes memory operatorData
	) private view returns (bool) {
		if (to.code.length > 0) {
			(bool success, bytes memory reason) = _canReceive(
				partition,
				operator,
				from,
				to,
				amount,
				data,
				operatorData
			);
			if (!success) {
				if (reason.length == 0) {
					revert("ERC1400: transfer to non ERC1400Receiver implementer");
				} else {
					//solhint-disable no-inline-assembly
					assembly {
						revert(add(32, reason), mload(reason))
					}
				}
			}
			return true;
		}
		return true;
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
