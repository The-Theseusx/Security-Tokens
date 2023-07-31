//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import { Ownable2Step } from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { Context } from "openzeppelin-contracts/contracts/utils/Context.sol";
import { ERC165 } from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { IERC1400NFT } from "./IERC1400NFT.sol";

/**
 * @dev ERC1400 compatible with ERC721 for non-fungible security tokens.
 * @dev Each token Id must be unique irrespective of partition.
 * @dev A token id issued to the default partition cannot be issued to any other partition.
 */

///@dev use OZ's Context contract
contract ERC1400NFT is Context, Ownable2Step, ERC165 {
	using Strings for uint256;
	///@dev Default token partition
	bytes32 public constant DEFAULT_PARTITION = bytes32(0);

	///@dev token name
	string private _name;

	///@dev token symbol
	string private _symbol;

	///@dev token contract version for EIP712
	string private _version;

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

	///@dev mapping of user to mapping of partition in _partitionsOf array to index of partition in this array.
	mapping(address => mapping(bytes32 => uint256)) private _partitionIndexOfUser;

	///@dev mapping from token ID to partition to approved address
	mapping(uint256 => mapping(bytes32 => address)) private _tokenApprovalsByPartition;

	///@dev mapping from owner to operator approvals
	mapping(address => mapping(address => bool)) private _operatorApprovals;

	///@dev mapping of used nonces
	mapping(address => uint256) private _userNonce;

	constructor(string memory name_, string memory symbol_, string memory baseUri_, string memory version_) {
		require(bytes(name_).length != 0, "ERC1400NFT: name must not be empty");
		require(bytes(symbol_).length != 0, "ERC1400NFT: symbol must not be empty");
		require(bytes(version_).length != 0, "ERC1400NFT: version must not be empty");
		_name = name_;
		_symbol = symbol_;
		_baseUri = baseUri_;
		_version = version_;
		_isIssuable = true;
	}

	function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
		return interfaceId == type(IERC1400NFT).interfaceId || super.supportsInterface(interfaceId);
	}

	/// @return true if more tokens can be issued by the issuer, false otherwise.
	function isIssuable() public view virtual returns (bool) {
		return _isIssuable;
	}

	/**
	 * @dev Check whether the token is controllable by authorized controllers.
	 * @return bool 'true' if the token is controllable
	 */
	function isControllable() public view virtual returns (bool) {
		return _controllers.length != 0;
	}

	///@return the name of the token.
	function name() public view virtual returns (string memory) {
		return _name;
	}

	///@return the symbol of the token, usually a shorter version of the name.
	function symbol() public view virtual returns (string memory) {
		return _symbol;
	}

	///@return the contract version.
	function version() public view virtual returns (string memory) {
		return _version;
	}

	/**
	 * @return the total token balance of a user irrespective of partition.
	 */
	function balanceOf(address account) public view virtual returns (uint256) {
		require(account != address(0), "ERC1400NFT: balance query for the zero address");

		return _balances[account];
	}

	/**
	 * @param partition the token partition.
	 * @param user the address to check if it is the owner of the partition.
	 * @return true if the user is the owner of the partition, false otherwise.
	 */
	function isUserPartition(bytes32 partition, address user) public view virtual returns (bool) {
		return partition == _partitionsOf[user][_partitionIndexOfUser[user][partition]];
	}

	/**
	 * @return the balance of a user for a given partition, default partition inclusive.
	 */
	function balanceOfByPartition(bytes32 partition, address account) public view virtual returns (uint256) {
		require(account != address(0), "ERC1400NFT: balance query for the zero address");
		require(
			_partitions[_partitionIndex[partition]] == partition || partition == DEFAULT_PARTITION,
			"ERC1400NFT: nonexistent partition"
		);
		return _balancesByPartition[account][partition];
	}

	///@dev push default partition to index 0 of _partitions array ?

	function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
		require(exists(tokenId), "ERC1400NFT: tokenId does not exist");

		string memory baseURI = _baseUri;
		return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
	}

	function _changeBaseURI(string memory baseUri_) internal virtual {
		_baseUri = baseUri_;
	}

	function ownerOf(uint256 tokenId) public view virtual returns (address) {
		address owner = _ownerOf(tokenId);
		require(owner != address(0), "ERC1400NFT: invalid token ID");
		return owner;
	}

	/**
	 * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
	 */
	function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
		return _owners[tokenId];
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
	 * @dev Check if an operator is allowed to manage tokens of a given owner irrespective of partitions.
	 */
	function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
		return isOperator(operator, owner);
	}

	function isOperator(address operator, address account) public view virtual returns (bool) {
		return _operatorApprovals[account][operator];
	}

	function getApproved(uint256 tokenId) public view virtual returns (address) {
		require(exists(tokenId), "ERC1400NFT: nonexistent token");

		return _tokenApprovalsByPartition[tokenId][DEFAULT_PARTITION];
	}

	function setApprovalForAll(address operator, bool approved) public virtual {
		approved ? authorizeOperator(operator) : revokeOperator(operator);
	}

	/**
	 * @notice authorize an operator to use _msgSender()'s tokens irrespective of partitions.
	 * @notice this grants permission to the operator to transfer ALL tokens of _msgSender().
	 * @notice this includes burning tokens on behalf of the token holder.
	 * @param operator address to authorize as operator for caller.
	 */
	function authorizeOperator(address operator) public virtual {
		require(operator != _msgSender(), "ERC1400NFT: self authorization not allowed");
		_operatorApprovals[_msgSender()][operator] = true;
		//emit AuthorizedOperator(operator, _msgSender());
	}

	/**
	 * @notice revoke an operator's rights to use _msgSender()'s tokens irrespective of partitions.
	 * @notice this will revoke ALL operator rights of the _msgSender() however,
	 * @notice if the operator has been authorized to spend from a partition, this will not revoke those rights.
	 * @notice see 'revokeOperatorByPartition' to revoke partition specific rights.
	 * @param operator address to revoke as operator for caller.
	 */
	function revokeOperator(address operator) public virtual {
		_operatorApprovals[_msgSender()][operator] = false;
		//emit RevokedOperator(operator, _msgSender());
	}

	function approve(address to, uint256 tokenId) public virtual {
		address owner = _ownerOf(tokenId);
		require(to != owner, "ERC1400NFT: approval to current owner");
		///@dev maybe restrict all operator transfers to operatorTransfer so the appropriate events are emitted.
		require(
			_msgSender() == owner || isApprovedForAll(owner, _msgSender()),
			"ERC1400NFT: caller is not token owner or approved"
		);

		_approve(to, tokenId);
	}

	/**
	 * @dev Approve `to` to operate on `tokenId`
	 *
	 * Emits an {Approval} event.
	 */
	function _approve(address to, uint256 tokenId) internal virtual {
		_tokenApprovalsByPartition[tokenId][DEFAULT_PARTITION] = to;

		//emit Approval(ownerOf(tokenId), to, tokenId);
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
