//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { Context } from "openzeppelin-contracts/contracts/utils/Context.sol";
import { ERC165 } from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import { ERC1643 } from "../ERC1643/ERC1643.sol";
import { ERC1400NFTValidateDataParams } from "../utils/DataTypes.sol";
import { EIP712 } from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { IERC1400NFT } from "./IERC1400NFT.sol";
import { IERC1400NFTReceiver } from "./IERC1400NFTReceiver.sol";

/**
 * @dev ERC1400NFT compatible with ERC721 for non-fungible security tokens.
 * @dev Each token Id must be unique irrespective of partition.
 * @dev A token id issued to a partition cannot be issued to any other partition.
 */

contract ERC1400NFT is IERC1400NFT, Context, EIP712, ERC165, ERC1643 {
	using Strings for uint256;

	// --------------------------------------------------------------- CONSTANTS --------------------------------------------------------------- //
	///@dev Default token partition
	bytes32 public constant DEFAULT_PARTITION = bytes32(0);

	///@dev EIP712 typehash for data validation
	bytes32 public constant ERC1400NFT_DATA_VALIDATION_HASH =
		keccak256(
			"ERC1400NFTValidateData(address from,address to,uint256 tokenId,bytes32 partition,uint256 nonce,uint48 deadline)"
		);

	///@dev Access control role for token admin.
	bytes32 public constant ERC1400_NFT_ADMIN_ROLE = keccak256("ERC1400_NFT_ADMIN_ROLE");

	///@dev Access control role for the token issuer.
	bytes32 public constant ERC1400_NFT_ISSUER_ROLE = keccak256("ERC1400_NFT_ISSUER_ROLE");

	///@dev Access control role for the token redeemer.
	bytes32 public constant ERC1400_NFT_REDEEMER_ROLE = keccak256("ERC1400_NFT_REDEEMER_ROLE");

	///@dev Access control role for the token transfer agent. Transfer agents can authorize transfers with their signatures.
	bytes32 public constant ERC1400_NFT_TRANSFER_AGENT_ROLE = keccak256("ERC1400_NFT_TRANSFER_AGENT_ROLE");
	// --------------------------------------------------------- PRIVATE STATE VARIABLES --------------------------------------------------------- //

	///@dev token name
	string private _name;

	///@dev token symbol
	string private _symbol;

	///@dev base URI for computing {tokenURI}.
	string private _baseUri;

	///@dev should track if token is issuable or not. Should not be modifiable if false.
	bool private _isIssuable;

	///@dev array of token partitions.
	bytes32[] private _partitions;

	///@dev array of token controllers.
	address[] private _controllers;

	///@dev mapping from token ID to owner address
	mapping(uint256 => address) private _owners;

	///@dev mapping owner address to token count
	mapping(address => uint256) private _balances;

	///@dev mapping of owner to partition to token count
	mapping(address => mapping(bytes32 => uint256)) private _balancesByPartition;

	///@dev mapping of partition to index in _partitions array.
	mapping(bytes32 => uint256) private _partitionIndex;

	///@dev mapping of controller to index in _controllers array.
	mapping(address => uint256) private _controllerIndex;

	///@dev mapping from user to array of partitions.
	mapping(address => bytes32[]) private _partitionsOf;

	///@dev mapping of token ID to partition.
	mapping(uint256 => bytes32) private _partitionOfToken;

	///@dev mapping of user to mapping of partition in _partitionsOf array to index of partition in this array.
	mapping(address => mapping(bytes32 => uint256)) private _partitionIndexOfUser;

	///@dev mapping from token ID to partition to approved address
	mapping(uint256 => mapping(bytes32 => address)) private _tokenApprovalsByPartition;

	///@dev mapping from owner to operator approvals
	mapping(address => mapping(address => bool)) private _operatorApprovals;

	///@dev mapping from owner to partition to operator approvals
	mapping(address => mapping(bytes32 => mapping(address => bool))) private _operatorApprovalsByPartition;

	///@dev mapping of used nonces
	mapping(bytes32 => uint256) private _roleNonce;

	// --------------------------------------------------------------- EVENTS --------------------------------------------------------------- //
	///@dev event emitted when tokens are transferred with data attached
	event TransferWithData(address indexed from, address indexed to, uint256 tokenId, bytes data);

	///@dev event emitted when issuance is disabled
	event IssuanceDisabled();
	event Transfer(
		address operator,
		address indexed from,
		address indexed to,
		uint256 tokenId,
		bytes32 indexed partition,
		bytes data,
		bytes operatorData
	);
	event Approval(address indexed owner, address indexed spender, uint256 tokenId, bytes32 indexed partition);
	event ControllerAdded(address indexed controller);
	event ControllerRemoved(address indexed controller);
	event ControllerTransferByPartition(
		bytes32 indexed partition,
		address indexed controller,
		address indexed from,
		address to,
		uint256 tokenId,
		bytes data,
		bytes operatorData
	);
	event ControllerRedemptionByPartition(
		bytes32 indexed partition,
		address indexed controller,
		address indexed tokenHolder,
		uint256 tokenId,
		bytes data,
		bytes operatorData
	);
	event ChangedPartition(
		address operator,
		bytes32 indexed partitionFrom,
		bytes32 indexed partitionTo,
		address indexed account,
		uint256 tokenId,
		bytes data,
		bytes operatorData
	);
	event NonceSpent(bytes32 indexed role, address indexed spender, uint256 nonceSpent);

	// --------------------------------------------------------------- MODIFIERS --------------------------------------------------------------- //

	modifier onlyController() {
		require(
			_controllers.length != 0 && _controllers[_controllerIndex[_msgSender()]] == _msgSender(),
			"ERC1400NFT: not a controller"
		);
		_;
	}

	modifier isValidPartition(bytes32 partition) {
		require(
			partition == DEFAULT_PARTITION ||
				(_partitions.length != 0 && _partitions[_partitionIndex[partition]] == partition),
			"ERC1400NFT: nonexistent partition"
		);
		_;
	}

	modifier isOwnerOrApproved(address spender, uint256 tokenId) {
		require(
			ownerOf(tokenId) == _msgSender() || getApproved(tokenId) == spender,
			"ERC1400NFT: not owner or approved"
		);
		_;
	}

	// --------------------------------------------------------------- CONSTRUCTOR --------------------------------------------------------------- //

	constructor(
		string memory name_,
		string memory symbol_,
		string memory baseUri_,
		string memory version_,
		address tokenAdmin_,
		address tokenIssuer_,
		address tokenRedeemer_,
		address tokenTransferAgent_
	) EIP712(name_, version_) ERC1643(tokenAdmin_, ERC1400_NFT_ADMIN_ROLE) {
		require(bytes(name_).length != 0, "ERC1400NFT: invalid name");
		require(bytes(symbol_).length != 0, "ERC1400NFT: no symbol");
		require(bytes(version_).length != 0, "ERC1400NFT: invalid version");
		require(tokenAdmin_ != address(0), "ERC1400NFT: invalid token admin");
		require(tokenIssuer_ != address(0), "ERC1400NFT: invalid token issuer");
		require(tokenRedeemer_ != address(0), "ERC1400NFT: invalid token redeemer");
		require(tokenTransferAgent_ != address(0), "ERC1400NFT: invalid token transfer agent");

		_name = name_;
		_symbol = symbol_;
		_baseUri = baseUri_;
		_isIssuable = true;

		_grantRole(DEFAULT_ADMIN_ROLE, tokenAdmin_); ///@dev give default admin role to token admin
		_grantRole(ERC1400_NFT_ADMIN_ROLE, tokenAdmin_); ///@dev token admin role. Recommended over DEFAULT_ADMIN_ROLE.
		_grantRole(ERC1400_NFT_ISSUER_ROLE, tokenIssuer_);
		_grantRole(ERC1400_NFT_REDEEMER_ROLE, tokenRedeemer_);
		_grantRole(ERC1400_NFT_TRANSFER_AGENT_ROLE, tokenTransferAgent_);

		_setRoleAdmin(ERC1400_NFT_ADMIN_ROLE, ERC1400_NFT_ADMIN_ROLE);
		_setRoleAdmin(ERC1400_NFT_ISSUER_ROLE, ERC1400_NFT_ADMIN_ROLE);
		_setRoleAdmin(ERC1400_NFT_REDEEMER_ROLE, ERC1400_NFT_ADMIN_ROLE);
		_setRoleAdmin(ERC1400_NFT_TRANSFER_AGENT_ROLE, ERC1400_NFT_ADMIN_ROLE);
	}

	// --------------------------------------------------------------- PUBLIC GETTERS --------------------------------------------------------------- //

	function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, AccessControl) returns (bool) {
		return interfaceId == type(IERC1400NFT).interfaceId || super.supportsInterface(interfaceId);
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

	function domainSeparator() public view virtual returns (bytes32) {
		return _domainSeparatorV4();
	}

	/// @return the total token balance of a user irrespective of partition.
	function balanceOf(address account) public view virtual override returns (uint256) {
		require(account != address(0), "ERC1400NFT: zero address");

		return _balances[account];
	}

	/// @return the total number of tokens of a user for a given partition, default partition inclusive.
	function balanceOfByPartition(
		bytes32 partition,
		address account
	) public view virtual override isValidPartition(partition) returns (uint256) {
		require(account != address(0), "ERC1400NFT: zero address");

		return _balancesByPartition[account][partition];
	}

	/// @return the total number of tokens of a user for the default partition.
	function balanceOfNonPartitioned(address account) public view virtual returns (uint256) {
		return _balancesByPartition[account][DEFAULT_PARTITION];
	}

	/// @return the total number of partitions of this token excluding the default partition.
	function totalPartitions() public view virtual returns (uint256) {
		return _partitions.length;
	}

	/// @return the list of partitions of @param account.
	function partitionsOf(address account) public view virtual override returns (bytes32[] memory) {
		return _partitionsOf[account];
	}

	/// @return the partition of @param tokenId.
	function partitionOfToken(uint256 tokenId) public view virtual returns (bytes32) {
		require(exists(tokenId), "ERC1400NFT: non-existing token");

		return _partitionOfToken[tokenId];
	}

	/// @return the list of controllers of this token.
	function getControllers() public view virtual returns (address[] memory) {
		return _controllers;
	}

	/// @return true if @param controller is a controller of this token.
	function isController(address controller) public view virtual returns (bool) {
		return _controllers.length != 0 && controller == _controllers[_controllerIndex[controller]];
	}

	/// @return the nonce of a role.
	function getRoleNonce(bytes32 role) public view virtual returns (uint256) {
		return _roleNonce[role];
	}

	/**
	 * @param partition the partition to check for.
	 * @param user the address to check whether it has @param partition in its list of partitions.
	 * @return true if the user is the owner of the partition, false otherwise.
	 */
	function isUserPartition(
		bytes32 partition,
		address user
	) public view virtual isValidPartition(partition) returns (bool) {
		return (_partitionsOf[user].length != 0 &&
			partition == _partitionsOf[user][_partitionIndexOfUser[user][partition]]);
	}

	/**
	 * @param tokenId the token Id.
	 * @return the token uri of a given tokenId.
	 */
	function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
		require(exists(tokenId), "ERC1400NFT: tokenId does not exist");

		string memory baseURI = _baseUri;
		return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
	}

	/**
	 * @param tokenId the token Id.
	 * @return the owner of a tokenId. Reverts if the token does not exist.
	 */
	function ownerOf(uint256 tokenId) public view virtual returns (address) {
		address owner = _ownerOf(tokenId);
		require(owner != address(0), "ERC1400NFT: invalid token ID");
		return owner;
	}

	/**
	 * @dev Returns whether `tokenId` exists.
	 * Tokens start existing when they are minted,
	 * and stop existing when they are burned.
	 */
	function exists(uint256 tokenId) public view virtual returns (bool) {
		return _ownerOf(tokenId) != address(0);
	}

	/**
	 * @param owner the current owner of the token.
	 * @param operator the operator to check for.
	 * @return true if an operator is allowed to manage tokens of a given owner irrespective of partitions.
	 */
	function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
		return isOperator(operator, owner);
	}

	/**
	 * @param operator the operator to check for.
	 * @param account the current account to check if the operator is allowed to manage tokens of.
	 * @return true if an operator is allowed to manage tokens of a given owner irrespective of partitions.
	 */ function isOperator(address operator, address account) public view virtual override returns (bool) {
		return _operatorApprovals[account][operator];
	}

	/**
	 * @param partition the partition to check for.
	 * @param operator the operator to check for.
	 * @param account the current account to check if the operator is allowed to manage tokens of.
	 * @return true if the operator address is allowed to control tokens of a partition on behalf of the tokenHolder.
	 */
	function isOperatorForPartition(
		bytes32 partition,
		address operator,
		address account
	) public view virtual override isValidPartition(partition) returns (bool) {
		return _operatorApprovalsByPartition[account][partition][operator];
	}

	/**
	 * @param tokenId the token Id.
	 * @return an address approved to transfer @param tokenId
	 */
	function getApproved(uint256 tokenId) public view virtual returns (address) {
		require(exists(tokenId), "ERC1400NFT: nonexistent token");

		return _tokenApprovalsByPartition[tokenId][partitionOfToken(tokenId)];
	}

	/**
	* @notice Error messages:
	  -IP: Invalid partition
	  -ITP: Invalid token partition
	  -IS: Invalid sender
	  -ITO: Invalid token owner
	  -ITA: Invalid transfer agent (operator)
	  -IR: Invalid receiver
	  -ITD: Invalid transfer data
	  -NAT: Not approved to transfer token (allowance)
	  -ITID: Invalid token Id

	 * @param from token holder.
	 * @param to token recipient.
	 * @param partition token partition.
	 * @param tokenId tokenId to transfer.
	 * @param data information attached to the transfer, by the token holder.
	 */
	function canTransferByPartition(
		///@dev review ERC1066 error codes used.
		address from,
		address to,
		bytes32 partition,
		uint256 tokenId,
		bytes memory data
	) public view virtual override returns (bytes memory, bytes32, bytes32) {
		address operator = _msgSender();

		if (_partitions[_partitionIndex[partition]] != partition || partitionOfToken(tokenId) != partition) {
			return ("0x50", "ERC1400NFT: IP", partition);
		}
		if (ownerOf(tokenId) != from) return ("0x52", "ERC1400NFT: ITO", partition);
		if (from == address(0)) return ("0x56", "ERC1400NFT: IS", partition);
		if (to == address(0)) return ("0x57", "ERC1400NFT: IR", partition);
		if (to.code.length != 0) {
			(bool can, ) = _canReceive(partition, operator, from, to, tokenId, data, "");
			if (!can) return ("0x57", "ERC1400NFT: IR", partition);
		}
		if (!exists(tokenId)) return ("0x50", "ERC1400NFT: ITID", partition);
		address approvedSpender = getApproved(tokenId);
		if (ownerOf(tokenId) != operator && operator != approvedSpender) {
			if (
				!isOperator(operator, from) ||
				!isOperatorForPartition(partition, operator, from) ||
				!isController(operator)
			) {
				if (approvedSpender != to) {
					return ("0x53", "ERC1400NFT: NAT", partition);
				}
				///@dev see transferFromByPartition to understand why this should return a transfer failure.
				return ("0x58", "ERC1400NFT: ITA", partition);
			}
		}

		if (data.length != 0) {
			ERC1400NFTValidateDataParams memory _data = ERC1400NFTValidateDataParams({
				authorizerRole: ERC1400_NFT_TRANSFER_AGENT_ROLE,
				from: from,
				to: to,
				tokenId: tokenId,
				partition: partition,
				data: data
			});
			(bool can, ) = _validateData(_data);
			if (!can) return ("0x5f", "ERC1400NFT: ITD", partition);
		}

		return ("0x51", "ERC1400NFT: CT", partition);
	}

	/**
	 **code	description **
	 * 0x50	transfer failure
	 * 0x51	transfer success
	 * 0x52	insufficient balance
	 * 0x53	insufficient allowance
	 * 0x54	transfers halted (contract paused)
	 * 0x55	funds locked (lockup period)
	 * 0x56	invalid sender
	 * 0x57	invalid receiver
	 * 0x58	invalid operator (transfer agent)
	 * 0x59
	 * 0x5a
	 * 0x5b
	 * 0x5a
	 * 0x5b
	 * 0x5c
	 * 0x5d
	 * 0x5e
	 * 0x5f	token meta or info
	 */
	/**
	 * @notice Check if a transfer of a token of the default partition is possible.
	 * @param to token recipient.
	 * @param tokenId the token Id.
	 * @param data information attached to the transfer, by the token holder.
	 */
	function canTransfer(
		address to,
		uint256 tokenId,
		bytes memory data
	) public view virtual override returns (bool, bytes memory, bytes32) {
		address operator = _msgSender();

		if (to == address(0)) return (false, bytes("0x57"), bytes32(0));
		if (!exists(tokenId)) return (false, bytes("0x50"), bytes32(0));
		///@dev if you are not the owner, you must be an operator or controller.
		if (ownerOf(tokenId) != operator) {
			if (
				!isOperator(operator, ownerOf(tokenId)) ||
				!isOperatorForPartition(DEFAULT_PARTITION, operator, ownerOf(tokenId)) ||
				!isController(operator)
			) {
				return (false, bytes("0x58"), bytes32(0));
			}
		}
		if (partitionOfToken(tokenId) != DEFAULT_PARTITION) return (false, bytes("0x50"), bytes32(0));
		if (to.code.length > 0) {
			(bool can, ) = _canReceive(DEFAULT_PARTITION, operator, operator, to, tokenId, data, "");
			if (!can) return (false, bytes("0x57"), bytes32(0));
		}

		return (true, bytes("0x51"), bytes32(0));
	}

	/**
	 * @notice Check if a transfer from of tokens of the default partition is possible.
	 * @param from token holder.
	 * @param to token recipient.
	 * @param tokenId the token Id.
	 * @param data information attached to the transfer.
	 */
	function canTransferFrom(
		address from,
		address to,
		uint256 tokenId,
		bytes memory data
	) public view virtual override returns (bool, bytes memory, bytes32) {
		address operator = _msgSender();

		if (from == address(0)) return (false, "0x56", bytes32(0));
		if (to == address(0)) return (false, "0x57", bytes32(0));
		if (to.code.length > 0) {
			(bool can, ) = _canReceive(DEFAULT_PARTITION, operator, from, to, tokenId, data, "");
			if (!can) return (false, "0x57", bytes32(0));
		}
		if (!exists(tokenId)) return (false, "0x50", bytes32(0));
		if (ownerOf(tokenId) != from) return (false, "0x52", bytes32(0));
		address approvedSpender = getApproved(tokenId);
		if (ownerOf(tokenId) != operator && operator != approvedSpender) {
			if (
				!isOperator(operator, from) ||
				!isOperatorForPartition(DEFAULT_PARTITION, operator, from) ||
				!isController(operator)
			) {
				if (approvedSpender != to) {
					return (false, "ERC1400NFT: NAT", DEFAULT_PARTITION);
				}
				///@dev see transferFrom to understand why this should return a transfer failure.
				return (false, "ERC1400NFT: ITA", DEFAULT_PARTITION);
			}
		}
		if (data.length != 0) {
			ERC1400NFTValidateDataParams memory _data = ERC1400NFTValidateDataParams({
				authorizerRole: ERC1400_NFT_TRANSFER_AGENT_ROLE,
				from: from,
				to: to,
				tokenId: tokenId,
				partition: DEFAULT_PARTITION,
				data: data
			});
			(bool can, ) = _validateData(_data);
			if (!can) return (false, "0x5f", bytes32(0));
		}
		return (true, "0x51", bytes32(0));
	}

	/**
	 * @notice considering the different return data formats of 
	 * IERC1594 canTransfer, IERC1594 canTransferFrom and IERC1410 canTransferByPartition, 
	 * this method tries to combine all into one canTransfer function.
	 
	 * @param partition the partition @param tokenId is associated with.
	 * @param from the address to transfer from
	 * @param to the address to transfer to
	 * @param tokenId the tokenId to transfer
	 * @param data transfer data.
	 * @param validateData if true, will validate the data as a signature authorizing the transfer.
	 * @param data the data to validate as a signature authorizing the transfer or extra metadata to go with the transfer.
	 * @return bool if the transfer is possible with no error message else false with the error message.
	 */
	function canTransfer(
		bytes32 partition,
		address from,
		address to,
		uint256 tokenId,
		bool validateData,
		bytes memory data
	) public view virtual returns (bool, string memory) {
		bytes memory message;

		if (partition == DEFAULT_PARTITION) {
			if (from == to) {
				(bool can, bytes memory returnedMessage, ) = canTransfer(to, tokenId, data);
				if (can) return (true, "");
				message = returnedMessage;
			} else {
				(bool can, bytes memory returnedMessage, ) = canTransferFrom(from, to, tokenId, data);
				if (can) return (true, "");
				message = returnedMessage;
			}
		} else {
			(bytes memory returnedMessage, , ) = canTransferByPartition(from, to, partition, tokenId, data);
			if (keccak256(returnedMessage) == keccak256("0x51")) return (true, "");
			message = returnedMessage;
		}

		if (keccak256(message) == keccak256("0x50")) {
			return (false, "ERC1400NFT: Invalid tokenId, partition or transfer failure");
		}
		if (keccak256(message) == keccak256("0x52")) return (false, "ERC1400NFT: Not token owner");
		if (keccak256(message) == keccak256("0x53")) return (false, "ERC1400NFT: Spender not approved");
		if (keccak256(message) == keccak256("0x56")) return (false, "ERC1400NFT: Invalid sender");
		if (keccak256(message) == keccak256("0x57")) return (false, "ERC1400NFT: Cannot receive");
		if (keccak256(message) == keccak256("0x58")) return (false, "ERC1400NFT: Invalid transfer agent");
		if (keccak256(message) == keccak256("0x5f")) {
			return validateData ? (false, "ERC1400NFT: Invalid transfer data") : (true, "");
		}

		return (false, "ERC1400NFT: Failed with unknown error");
	}

	// --------------------------------------------------------------- TRANSFERS --------------------------------------------------------------- //
	/**
	 * @notice transfer tokens from the default partition with additional data.
	 * @param to the address to transfer tokens to
	 * @param tokenId the tokenId to transfer
	 * @param data transfer data.
	 */
	function transferWithData(address to, uint256 tokenId, bytes memory data) public virtual override {
		address operator = _msgSender();
		require(data.length != 0, "ERC1400NFT: Invalid transfer data");
		_transferWithData(operator, operator, to, tokenId, data, "");
	}

	/**
	 * @param from the address to transfer @param tokenId from
	 * @param to the address to transfer @param tokenId to
	 * @param tokenId the transfer to transfer
	 * @notice transfers from the default partition, see transferByPartitionFrom to transfer from a non-default partition.
	 */
	function transferFrom(address from, address to, uint256 tokenId) public virtual isOwnerOrApproved(to, tokenId) {
		_transfer(_msgSender(), from, to, tokenId, "", "");
	}

	/**
	 * @notice transfers from the default partition with data.
	 * @param from the address to transfer from
	 * @param to the address to transfer to
	 * @param tokenId the id of the token to transfer
	 * @param data transfer data to be validated.
	 */
	function transferFromWithData(
		address from,
		address to,
		uint256 tokenId,
		bytes memory data
	) public virtual override isOwnerOrApproved(to, tokenId) {
		_transferWithData(_msgSender(), from, to, tokenId, data, "");
	}

	/**
	 * @notice since msg.sender is the token holder, the data argument would be empty ("") unless the token holder wishes to send additional metadata.
	 * @param partition the partition tokenId is associated with.
	 * @param to the address to transfer to
	 * @param tokenId of the token to transfer
	 * @param data transfer data.
	 */
	function transferByPartition(
		bytes32 partition,
		address to,
		uint256 tokenId,
		bytes memory data
	) public virtual override isValidPartition(partition) returns (bytes32) {
		address operator = _msgSender();

		_transferByPartition(partition, operator, operator, to, tokenId, data, "");
		return partition;
	}

	/**
	 * @notice since an authorized body might be forcing a token transfer from a different address, 
	   the @param data could be a signature authorizing the transfer.
	 * @notice in the case of a forced transfer, the data would be a signature authorizing the transfer hence the data must be validated.
	 * @notice if it is a normal transferFrom, the operator data would be empty ("").
	 * @param partition the partition @param tokenId is associated with.
	 * @param from the address to transfer from
	 * @param to the address to transfer to
	 * @param tokenId the tokenId to transfer
	 * @param data transfer data.
	 */
	function transferFromByPartition(
		bytes32 partition,
		address from,
		address to,
		uint256 tokenId,
		bytes memory data
	) public virtual isValidPartition(partition) returns (bytes32) {
		address operator = _msgSender();

		if (data.length != 0) {
			ERC1400NFTValidateDataParams memory _data = ERC1400NFTValidateDataParams({
				authorizerRole: ERC1400_NFT_TRANSFER_AGENT_ROLE,
				from: from,
				to: to,
				tokenId: tokenId,
				partition: partition,
				data: data
			});
			(bool authorized, address authorizer) = _validateData(_data);
			require(authorized, "ERC1400NFT: Invalid data");
			_spendNonce(ERC1400_NFT_TRANSFER_AGENT_ROLE, authorizer);
			_transferByPartition(partition, operator, from, to, tokenId, data, "");
			return partition;
		}
		require(
			ownerOf(tokenId) == operator || getApproved(tokenId) == to,
			"ERC1400NFT: caller is not owner or approved"
		);
		_transferByPartition(partition, operator, from, to, tokenId, data, "");
		return partition;
	}

	/**
	 * @param partition the partition @param tokenId is asscoiated with.
	 * @param from the address to transfer from
	 * @param to the address to transfer to
	 * @param tokenId the tokenId to transfer
	 * @param data transfer data.
	 * @param operatorData additional data attached by the operator (if any)
	 * @notice since msg.sender is supposed to be an authorized operator,
	 * @param data and @param operatorData would be 0x unless the operator wishes to send additional metadata.
	 */
	function operatorTransferByPartition(
		bytes32 partition,
		address from,
		address to,
		uint256 tokenId,
		bytes memory data,
		bytes memory operatorData
	) public virtual override isValidPartition(partition) returns (bytes32) {
		address operator = _msgSender();

		require(_operatorApprovalsByPartition[from][partition][operator], "ERC1400NFT: Not authorized operator");
		_transferByPartition(partition, operator, from, to, tokenId, data, operatorData);
		return partition;
	}

	/**
	 * @notice for controllers to transfer tokens of the default partition.
	 * @param from the address to transfer from
	 * @param to the address to transfer to
	 * @param tokenId the tokenId to transfer
	 * @param data additional transfer data.
	 * @param operatorData additional data attached by the operator (if any)
	 */
	function controllerTransfer(
		address from,
		address to,
		uint256 tokenId,
		bytes memory data,
		bytes memory operatorData
	) public virtual override onlyController {
		address operator = _msgSender();

		_transfer(operator, from, to, tokenId, data, operatorData);

		emit ControllerTransfer(operator, from, to, tokenId, data, operatorData);
	}

	/**
	 * @notice for controllers to transfer tokens of a given partition but the default partition.
	 * @param partition the  partition @param tokenId is associated with.
	 * @param from the address to transfer from
	 * @param to the address to transfer to
	 * @param tokenId the tokenId to transfer
	 * @param data additional transfer data.
	 * @param operatorData additional data attached by the operator (if any)
	 */
	function controllerTransferByPartition(
		bytes32 partition,
		address from,
		address to,
		uint256 tokenId,
		bytes memory data,
		bytes memory operatorData
	) public virtual onlyController isValidPartition(partition) {
		address operator = _msgSender();

		_transferByPartition(partition, operator, from, to, tokenId, data, operatorData);

		emit ControllerTransferByPartition(partition, operator, from, to, tokenId, data, operatorData);
	}

	// -------------------------------------------- APPROVALS, ALLOWANCES & OPERATORS -------------------------------------------- //

	function approve(address to, uint256 tokenId) public virtual {
		address owner = _ownerOf(tokenId);
		require(_msgSender() == owner, "ERC1400NFT: caller is not token owner ");
		require(to != owner, "ERC1400NFT: approval to current owner");
		require(partitionOfToken(tokenId) == DEFAULT_PARTITION, "ERC1400NFT: token is not in the default partition");
		_approve(owner, to, tokenId);
	}

	/**
	 * @notice approve a to to transfer tokens from any partition but the default one.
	 * @param partition the partition @param tokenId is associated with.
	 * @param to the address to approve
	 * @param tokenId the tokenId to approve
	 * @return true if successful
	 */
	function approveByPartition(
		bytes32 partition,
		address to,
		uint256 tokenId
	) public virtual isValidPartition(partition) returns (bool) {
		require(partition != DEFAULT_PARTITION, "ERC1400NFT: approveByPartition default partition");
		address owner = _ownerOf(tokenId);
		require(_msgSender() == owner, "ERC1400NFT: caller is not token owner ");
		require(to != owner, "ERC1400NFT: approval to current owner");
		require(partitionOfToken(tokenId) == partition, "ERC1400NFT: not token partition");

		_approveByPartition(partition, owner, to, tokenId);
		return true;
	}

	///@dev backwards compatibility with ERC721
	function setApprovalForAll(address operator, bool approved) public virtual {
		approved ? authorizeOperator(operator) : revokeOperator(operator);
	}

	/**
	 * @notice authorize an operator to use msg.sender's tokens irrespective of partitions.
	 * @notice this grants permission to the operator to transfer ALL tokens of msg.sender.
	 * @notice this includes burning tokens on behalf of the token holder.
	 * @param operator address to authorize as operator for caller.
	 */
	function authorizeOperator(address operator) public virtual override {
		address initiator = _msgSender();
		require(operator != initiator, "ERC1400NFT: self authorization not allowed");
		_operatorApprovals[initiator][operator] = true;
		emit AuthorizedOperator(operator, initiator);
	}

	/**
	 * @notice authorize an operator to use msg.sender's tokens of a given partition.
	 * @notice this grants permission to the operator to transfer tokens of msg.sender for a given partition.
	 * @notice this includes burning tokens of @param partition on behalf of the token holder.
	 * @param partition the token partition.
	 * @param operator address to authorize as operator for caller.
	 */
	function authorizeOperatorByPartition(
		bytes32 partition,
		address operator
	) public virtual override isValidPartition(partition) {
		address initiator = _msgSender();
		require(operator != initiator, "ERC1400NFT: self authorization not allowed");
		_operatorApprovalsByPartition[initiator][partition][operator] = true;
		emit AuthorizedOperatorByPartition(partition, operator, initiator);
	}

	/**
	 * @notice revoke an operator's rights to use msg.sender's tokens irrespective of partitions.
	 * @notice this will revoke ALL operator rights of the msg.sender however,
	 * @notice if the operator has been authorized to spend from a partition, this will not revoke those rights.
	 * @notice see 'revokeOperatorByPartition' to revoke partition specific rights.
	 * @param operator address to revoke as operator for caller.
	 */
	function revokeOperator(address operator) public virtual override {
		address initiator = _msgSender();
		_operatorApprovals[initiator][operator] = false;
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
		_operatorApprovalsByPartition[initiator][partition][operator] = false;
		emit RevokedOperatorByPartition(partition, operator, initiator);
	}

	/**
	 * @notice add controllers for the token.
	 */
	function addControllers(address[] memory controllers) external virtual onlyRole(ERC1400_NFT_ADMIN_ROLE) {
		uint256 controllersLength = controllers.length;
		uint256 i;

		for (; i < controllersLength; ) {
			require(controllers[i] != address(0), "ERC1400NFT: controller is zero address");
			require(
				_controllerIndex[controllers[i]] == 0 || _controllers.length == 0 || _controllers[0] != controllers[i],
				"ERC1400NFT: already controller"
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
	function removeControllers(address[] memory controllers) external virtual onlyRole(ERC1400_NFT_ADMIN_ROLE) {
		uint256 controllersLength = controllers.length;
		uint256 i;

		for (; i < controllersLength; ) {
			require(controllers[i] != address(0), "ERC1400NFT: controller is zero address");

			uint256 controllerIndex = _controllerIndex[controllers[i]];

			require(controllerIndex != 0 || _controllers[0] == controllers[i], "ERC1400NFT: not controller");

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

		if (userPartitionCount == 0) {
			for (; i < operatorCount; ) {
				if (isOperator(operators[i], operator)) revokeOperator(operators[i]);
				if (isOperatorForPartition(DEFAULT_PARTITION, operators[i], operator)) {
					revokeOperatorByPartition(DEFAULT_PARTITION, operators[i]);
				}
				unchecked {
					++i;
				}
			}
		}

		for (; i < userPartitionCount; ) {
			for (; j < operatorCount; ) {
				if (isOperatorForPartition(partitions[i], operators[j], operator)) {
					revokeOperatorByPartition(partitions[i], operators[j]);
				}

				if (isOperator(operators[j], operator)) {
					revokeOperator(operators[j]);
				}
				if (isOperatorForPartition(DEFAULT_PARTITION, operators[j], operator)) {
					revokeOperatorByPartition(DEFAULT_PARTITION, operators[j]);
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
	 * @dev disables issuance of tokens, can only be called by the owner
	 */
	function disableIssuance() public virtual onlyRole(ERC1400_NFT_ADMIN_ROLE) {
		_disableIssuance();
	}

	// -------------------------------------------------------------------- ISSUANCE -------------------------------------------------------------------- //

	/**
	 /**
	 * @notice allows the owner to issue tokens to an account from the default partition.
	 * @notice since owner is the only one who can issue tokens, no need to validate data as a signature?
	 * @param account the address to issue tokens to.
	 * @param tokenId the tokenId to issue.
	 * @param data additional data attached to the issue.
	 */
	function issue(
		address account,
		uint256 tokenId,
		bytes memory data
	) public virtual override onlyRole(ERC1400_NFT_ISSUER_ROLE) {
		_issueByPartition(DEFAULT_PARTITION, _msgSender(), account, tokenId, data);
	}

	/**
	 * @notice allows the owner to issue tokens to an account from a specific partition aside from the default partition.
	 * @param partition the token partition.
	 * @param account the address to issue tokens to.
	 * @param tokenId the tokenId to issue.
	 * @param data additional data attached to the issue.
	 */
	function issueByPartition(
		bytes32 partition,
		address account,
		uint256 tokenId,
		bytes memory data
	) public virtual override onlyRole(ERC1400_NFT_ISSUER_ROLE) {
		_issueByPartition(partition, _msgSender(), account, tokenId, data);
	}

	// -------------------------------------------------------------------- REDEMPTION -------------------------------------------------------------------- //

	/**
	 * @notice allows users to redeem token.
	 * @param tokenId the tokenId to redeem.
	 * @param data additional data attached to the transfer.
	 */
	function redeem(uint256 tokenId, bytes memory data) public virtual override {
		address operator = _msgSender();
		ERC1400NFTValidateDataParams memory _data = ERC1400NFTValidateDataParams({
			authorizerRole: ERC1400_NFT_REDEEMER_ROLE,
			from: operator,
			to: address(0),
			tokenId: tokenId,
			partition: DEFAULT_PARTITION,
			data: data
		});
		(bool authorized, address authorizer) = _validateData(_data);
		require(authorized, "ERC1400NFT: Invalid data");
		_spendNonce(ERC1400_NFT_REDEEMER_ROLE, authorizer);
		_redeemByPartition(DEFAULT_PARTITION, operator, operator, tokenId, data, "");
	}

	/**
	 * @notice allows authorized users to redeem token on behalf of someone else.
	 * @param tokenHolder the address to redeem token from.
	 * @param tokenId the tokenId to redeem.
	 * @param data additional data attached to the transfer.
	 */
	function redeemFrom(
		address tokenHolder,
		uint256 tokenId,
		bytes memory data
	) public virtual override onlyRole(ERC1400_NFT_REDEEMER_ROLE) {
		_redeemByPartition(DEFAULT_PARTITION, _msgSender(), tokenHolder, tokenId, data, "");
	}

	/**
	 * @notice allows users to redeem token. Redemptions should be approved by the issuer.
	 * @param partition the token partition to redeem from, this could be the default partition.
	 * @param tokenId the tokenId to redeem.
	 * @param data additional data attached to the transfer.
	 */
	function redeemByPartition(
		bytes32 partition,
		uint256 tokenId,
		bytes memory data
	) public virtual override isValidPartition(partition) {
		address operator = _msgSender();
		ERC1400NFTValidateDataParams memory _data = ERC1400NFTValidateDataParams({
			authorizerRole: ERC1400_NFT_REDEEMER_ROLE,
			from: operator,
			to: address(0),
			tokenId: tokenId,
			partition: partition,
			data: data
		});
		(bool authorized, address authorizer) = _validateData(_data);
		require(authorized, "ERC1400NFT: Invalid data");
		_spendNonce(ERC1400_NFT_REDEEMER_ROLE, authorizer);
		_redeemByPartition(partition, operator, operator, tokenId, data, "");
	}

	/**
	 * @param partition the token partition to redeem, this could be the default partition.
	 * @param account the address to redeem from
	 * @param tokenId the tokenId to redeem
	 * @param data redeem data.
	 * @param operatorData additional data attached by the operator (if any)
	 */
	function operatorRedeemByPartition(
		bytes32 partition,
		address account,
		uint256 tokenId,
		bytes memory data,
		bytes memory operatorData
	) public virtual override isValidPartition(partition) {
		address operator = _msgSender();

		ERC1400NFTValidateDataParams memory _data = ERC1400NFTValidateDataParams({
			authorizerRole: ERC1400_NFT_REDEEMER_ROLE,
			from: account,
			to: address(0),
			tokenId: tokenId,
			partition: partition,
			data: data
		});

		(bool authorized, address authorizer) = _validateData(_data);
		require(authorized, "ERC1400NFT: Invalid data");
		_spendNonce(ERC1400_NFT_REDEEMER_ROLE, authorizer);

		_redeemByPartition(partition, operator, account, tokenId, data, operatorData);
	}

	/**
	 * @notice allows controllers to redeem tokens of the default partition of users.
	 * @param tokenHolder the address to redeem token from.
	 * @param tokenId the tokenId to redeem.
	 * @param data additional data attached to the transfer.
	 * @param operatorData additional data attached by the operator (if any)
	 */
	function controllerRedeem(
		address tokenHolder,
		uint256 tokenId,
		bytes memory data,
		bytes memory operatorData
	) public virtual override onlyController {
		address operator = _msgSender();
		_redeemByPartition(DEFAULT_PARTITION, operator, tokenHolder, tokenId, data, operatorData);

		emit ControllerRedemption(operator, tokenHolder, tokenId, data, operatorData);
	}

	/**
	 * @notice allows controllers to redeem tokens of a given partition of users.
	 * @param partition the token partition to redeem.
	 * @param tokenHolder the address to redeem token from.
	 * @param tokenId the tokenId to redeem.
	 * @param data additional data attached to the transfer.
	 * @param operatorData additional data attached by the operator (if any)
	 */
	function controllerRedeemByPartition(
		bytes32 partition,
		address tokenHolder,
		uint256 tokenId,
		bytes memory data,
		bytes memory operatorData
	) public virtual onlyController isValidPartition(partition) {
		address operator = _msgSender();
		_redeemByPartition(partition, operator, tokenHolder, tokenId, data, operatorData);

		emit ControllerRedemptionByPartition(partition, operator, tokenHolder, tokenId, data, operatorData);
	}

	// ------------------------------------------------------- INTERNAL & PRIVATE FUNCTIONS ------------------------------------------------------- //

	/**
	 * @notice internal function to transfer tokens from the default partition.
	 * @param operator the address performing the transfer
	 * @param from the address to transfer tokens from
	 * @param to the address to transfer tokens to
	 * @param tokenId the id of the token to transfer
	 * @param data additional data attached to the transfer
	 * @param operatorData additional data attached to the transfer by the operator (if any)
	 */
	function _transfer(
		address operator,
		address from,
		address to,
		uint256 tokenId,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {
		require(to != address(0), "ERC1400NFT: transfer to the zero address");
		require(partitionOfToken(tokenId) == DEFAULT_PARTITION, "ERC1400NFT: token is not in the default partition");

		_beforeTokenTransfer(DEFAULT_PARTITION, operator, from, to, tokenId, data, operatorData);
		require(_ownerOf(tokenId) == from, "ERC1400NFT: transfer not from token owner");

		unchecked {
			_balancesByPartition[from][DEFAULT_PARTITION] -= 1;
			_balances[from] -= 1;

			_balancesByPartition[to][DEFAULT_PARTITION] += 1;
			_balances[to] += 1;
		}
		_owners[tokenId] = to;
		delete _tokenApprovalsByPartition[tokenId][DEFAULT_PARTITION];

		emit Transfer(operator, from, to, tokenId, DEFAULT_PARTITION, data, operatorData);

		_afterTokenTransfer(DEFAULT_PARTITION, operator, from, to, tokenId, data, operatorData);

		require(
			_checkOnERC1400NFTReceived(DEFAULT_PARTITION, operator, from, to, tokenId, data, operatorData),
			"ERC1400NFT: transfer to non ERC1400Receiver implementer"
		);
	}

	/**
	 * @dev transfers tokens from a sender to a recipient with data
	 */
	function _transferWithData(
		address operator,
		address from,
		address to,
		uint256 tokenId,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {
		_beforeTokenTransfer(DEFAULT_PARTITION, operator, from, to, tokenId, data, operatorData);
		ERC1400NFTValidateDataParams memory _data = ERC1400NFTValidateDataParams({
			authorizerRole: ERC1400_NFT_TRANSFER_AGENT_ROLE,
			from: from,
			to: to,
			tokenId: tokenId,
			partition: DEFAULT_PARTITION,
			data: data
		});

		(bool authorized, address authorizer) = _validateData(_data);
		require(authorized, "ERC1400NFT: Invalid data");
		_spendNonce(ERC1400_NFT_TRANSFER_AGENT_ROLE, authorizer);

		_transfer(operator, from, to, tokenId, data, operatorData);
		emit TransferWithData(_msgSender(), to, tokenId, data);

		_afterTokenTransfer(DEFAULT_PARTITION, operator, from, to, tokenId, data, operatorData);
	}

	/**
	 * @notice internal function to transfer tokens from any partition but the default one.
	 * @param partition the partition to transfer tokens from
	 * @param operator the address performing the transfer
	 * @param from the address to transfer tokens from
	 * @param to the address to transfer tokens to
	 * @param tokenId the Id of the token to transfer
	 * @param data additional data attached to the transfer
	 * @param operatorData additional data attached to the transfer by the operator (if any)
	 */
	function _transferByPartition(
		bytes32 partition,
		address operator,
		address from,
		address to,
		uint256 tokenId,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {
		require(partition != DEFAULT_PARTITION, "ERC1400NFT: Wrong partition (DEFAULT_PARTITION)");
		require(partitionOfToken(tokenId) == partition, "ERC1400NFT: token is not in the given partition");
		require(to != address(0), "ERC1400NFT: transfer to the zero address");
		if (operator != from) {
			require(
				isOperatorForPartition(partition, operator, from) ||
					isOperator(operator, from) ||
					isController(operator),
				"ERC1400NFT: not an operator or controller for partition"
			);
		}

		_beforeTokenTransfer(partition, operator, from, to, tokenId, data, operatorData);
		require(_ownerOf(tokenId) == from, "ERC1400NFT: transfer not from token owner");

		_balancesByPartition[from][partition] -= 1;
		_balances[from] -= 1;

		if (!isUserPartition(partition, to)) {
			_partitionIndexOfUser[to][partition] = _partitionsOf[to].length;
			_partitionsOf[to].push(partition);
		}

		_balancesByPartition[to][partition] += 1;
		_balances[to] += 1;
		_owners[tokenId] = to;
		delete _tokenApprovalsByPartition[tokenId][partition];

		emit TransferByPartition(partition, operator, from, to, tokenId, data, operatorData);

		_afterTokenTransfer(partition, operator, from, to, tokenId, data, operatorData);

		require(
			_checkOnERC1400NFTReceived(partition, operator, from, to, tokenId, data, operatorData),
			"ERC1400NFT: transfer to non ERC1400NFTReceiver implementer"
		);
	}

	/**
	 * @notice change the partition of a token given a token ID
	 * @param partitionFrom the current partition of the tokens
	 * @param partitionTo the partition to change tokens to
	 * @param operator the address performing the change
	 * @param account the address holding the tokens
	 * @param tokenId the Id of the token to change
	 * @param data additional data attached to the change
	 * @param operatorData additional data attached to the change by the operator (if any)
	 */
	function _changePartition(
		bytes32 partitionFrom,
		bytes32 partitionTo,
		address operator,
		address account,
		uint256 tokenId,
		bytes memory data,
		bytes memory operatorData
	) internal virtual isValidPartition(partitionFrom) isValidPartition(partitionTo) {
		if (operator != account) {
			require(
				isOperatorForPartition(partitionFrom, operator, account) ||
					isOperator(operator, account) ||
					isController(operator),
				"ERC1400NFT: not operator or controller for partition"
			);
		}

		require(partitionOfToken(tokenId) == partitionFrom, "ERC1400NFT: Invalid token partition");
		require(ownerOf(tokenId) == account, "ERC1400NFT: not token owner");

		_balancesByPartition[account][partitionFrom] -= 1;
		_balancesByPartition[account][partitionTo] += 1;

		_partitionOfToken[tokenId] = partitionTo;

		emit ChangedPartition(operator, partitionFrom, partitionTo, account, tokenId, data, operatorData);
	}

	function _approve(address owner, address to, uint256 tokenId) internal virtual {
		_approveByPartition(DEFAULT_PARTITION, owner, to, tokenId);
	}

	/**
	 * @notice internal approve function for any partition, including the default one
	 * @param partition the partition to spend tokens from
	 * @param owner the address that holds the tokens to be spent
	 * @param to the address that will spend the tokens
	 * @param tokenId the tokenId of tokens to be spent
	 */
	function _approveByPartition(bytes32 partition, address owner, address to, uint256 tokenId) internal virtual {
		_tokenApprovalsByPartition[tokenId][partition] = to;
		emit Approval(owner, to, tokenId, partition);
	}

	/**
	 * @notice internal function to issue tokens from any partition but the default one.
	 * @param partition the partition to associate @param tokenId with
	 * @param operator the address performing the issuance
	 * @param account the address to issue token to
	 * @param tokenId the tokenId to issue
	 * @param data additional data attached to the issuance
	 */
	function _issueByPartition(
		bytes32 partition,
		address operator,
		address account,
		uint256 tokenId,
		bytes memory data
	) internal virtual {
		require(account != address(0), "ERC1400NFT: Invalid recipient (zero address)");
		require(_isIssuable, "ERC1400NFT: Token is not issuable");
		require(!exists(tokenId), "ERC1400NFT: Token already exists");

		_beforeTokenTransfer(partition, operator, address(0), account, tokenId, data, "");

		_balances[account] += 1;
		_balancesByPartition[account][partition] += 1;
		_partitionOfToken[tokenId] = partition;
		_owners[tokenId] = account;

		_addTokenToPartitionList(partition, account);

		if (partition == DEFAULT_PARTITION) emit Issued(operator, account, tokenId, data);
		else emit IssuedByPartition(partition, operator, account, tokenId, data);
		_afterTokenTransfer(partition, operator, address(0), account, tokenId, data, "");

		require(
			_checkOnERC1400NFTReceived(partition, operator, address(0), account, tokenId, data, ""),
			"ERC1400NFT: transfer to non ERC1400NFTReceiver implementer"
		);
	}

	/**
	 * @notice internal function to update the contract token partition lists.
	 */
	function _addTokenToPartitionList(bytes32 partition, address account) internal virtual {
		bytes32[] memory partitions = _partitions;
		uint256 index = _partitionIndex[partition];

		bytes32 currentPartition = (index == 0 && partitions.length > 0) ? partitions[index] : DEFAULT_PARTITION;

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
	 * @notice internal function to redeem tokens of any partition including the default one.
	 * @param partition the partition to redeem tokens from
	 * @param operator the address performing the redemption
	 * @param account the address to redeem tokens from
	 * @param tokenId the tokenId to redeem
	 * @param data additional data attached to the redemption
	 * @param operatorData additional data attached to the redemption by the operator (if any)
	 */
	function _redeemByPartition(
		bytes32 partition,
		address operator,
		address account,
		uint256 tokenId,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {
		_beforeTokenTransfer(partition, operator, account, address(0), tokenId, data, operatorData);
		require(exists(tokenId), "ERC1400NFT: Token does not exist");
		require(_owners[tokenId] == account, "ERC1400NFT: Not token owner");
		if (operator != account) {
			require(
				isOperatorForPartition(partition, operator, account) ||
					isOperator(operator, account) ||
					isController(operator) ||
					hasRole(ERC1400_NFT_REDEEMER_ROLE, operator),
				"ERC1400NFT: transfer operator is not authorized"
			);
		}

		_balances[account] -= 1;
		_balancesByPartition[account][partition] -= 1;
		delete _partitionOfToken[tokenId];
		delete _owners[tokenId];
		delete _tokenApprovalsByPartition[tokenId][partition];

		if (!isController(operator)) {
			if (partition == DEFAULT_PARTITION) emit Redeemed(operator, account, tokenId, data);
			else emit RedeemedByPartition(partition, operator, account, tokenId, data, operatorData);
		}
		_afterTokenTransfer(partition, operator, account, address(0), tokenId, data, operatorData);
	}

	function _validateData(
		ERC1400NFTValidateDataParams memory validateDataParams
	) internal view virtual returns (bool, address) {
		(bytes memory signature, uint48 deadline) = abi.decode(validateDataParams.data, (bytes, uint48));
		require(deadline >= block.timestamp, "ERC1400NFT: Expired signature");

		bytes32 structData = keccak256(
			abi.encode(
				ERC1400NFT_DATA_VALIDATION_HASH,
				validateDataParams.from,
				validateDataParams.to,
				validateDataParams.tokenId,
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

	/// @dev internal function to disable issuance of tokens
	function _disableIssuance() internal virtual {
		_isIssuable = false;
		emit IssuanceDisabled();
	}

	function _changeBaseURI(string memory baseUri_) internal virtual {
		_baseUri = baseUri_;
	}

	/// @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
	function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
		return _owners[tokenId];
	}

	/**
	 * @notice checks if @param to can receive ERC1400NFT tokens.
	 * @param partition the partition @param tokenId is associated to
	 * @param operator the address performing the transfer
	 * @param from the address to transfer tokens from
	 * @param to the address to transfer tokens to, should be a contract
	 * @param tokenId the tokenId to transfer
	 * @param data additional data attached to the transfer
	 * @param operatorData additional data attached to the transfer by the operator (if any)
	 * @return bool 'true' if @param to can receive ERC1400NFT tokens, 'false' if not with corresponding revert data.
	 */
	function _canReceive(
		bytes32 partition,
		address operator,
		address from,
		address to,
		uint256 tokenId,
		bytes memory data,
		bytes memory operatorData
	) internal view virtual returns (bool, bytes memory) {
		try
			IERC1400NFTReceiver(to).onERC1400NFTReceived(partition, operator, from, to, tokenId, data, operatorData)
		returns (bytes4 retVal) {
			return (retVal == IERC1400NFTReceiver.onERC1400NFTReceived.selector, "");
		} catch (bytes memory reason) {
			return (false, reason);
		}
	}

	// --------------------------------------------------------------- HOOKS --------------------------------------------------------------- //

	/**
	 * @notice hook to be called to check if @param to can receive ERC1400NFT tokens. Reverts if not.
	 * @param partition the partition @param tokenId is associated to
	 * @param operator the address performing the transfer
	 * @param from the address to transfer tokens from
	 * @param to the address to transfer tokens to
	 * @param tokenId the tokenId to transfer
	 * @param data additional data attached to the transfer
	 * @param operatorData additional data attached to the transfer by the operator (if any)
	 */
	function _checkOnERC1400NFTReceived(
		bytes32 partition,
		address operator,
		address from,
		address to,
		uint256 tokenId,
		bytes memory data,
		bytes memory operatorData
	) private view returns (bool) {
		if (to.code.length > 0) {
			(bool success, bytes memory reason) = _canReceive(
				partition,
				operator,
				from,
				to,
				tokenId,
				data,
				operatorData
			);
			if (!success) {
				if (reason.length == 0) {
					revert("ERC1400NFT: transfer to non ERC1400NFTReceiver implementer");
				} else {
					//solhint-disable no-inline-assembly
					assembly {
						revert(add(32, reason), mload(reason))
					}
				}
			} else {
				return true;
			}
		}
		return true;
	}

	function _beforeTokenTransfer(
		bytes32 partition,
		address operator,
		address from,
		address to,
		uint256 tokenId,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {}

	function _afterTokenTransfer(
		bytes32 partition,
		address operator,
		address from,
		address to,
		uint256 tokenId,
		bytes memory data,
		bytes memory operatorData
	) internal virtual {}
}
