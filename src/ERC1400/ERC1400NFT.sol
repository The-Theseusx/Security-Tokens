//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import { Ownable2Step } from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { ERC165 } from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { IERC1400NFT } from "./IERC1400NFT.sol";

/**
 * @dev ERC1400 compatible with ERC721 for non-fungible security tokens.
 * @dev Each token Id must be unique irrespective of partition.
 * @dev A token id issued to the default partition cannot be issued to any other partition.
 */
contract ERC1400NFT is Ownable2Step, ERC165 {
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

	///@dev mapping from token ID to approved address
	mapping(uint256 => address) private _tokenApprovals;

	///@dev mapping from owner to operator approvals
	mapping(address => mapping(address => bool)) private _operatorApprovals;

	///@dev mapping from owner to partition to operator approvals
	mapping(address => mapping(bytes32 => mapping(address => bool))) private _operatorApprovalsByPartition;

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
	 * @return the balance of a user for a given partition, default partition inclusive.
	 */
	function balanceOfByPartition(bytes32 partition, address account) public view virtual returns (uint256) {
		require(account != address(0), "ERC1400NFT: balance query for the zero address");
		require(_partitionIndex[partition] != 0 || partition == DEFAULT_PARTITION, "ERC1400NFT: inexistent partition"); //!recheck
		return _balancesByPartition[account][partition];
	}

	///@dev push default partition to index 0 of _partitions array ?

	function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
		require(exists(tokenId), "ERC1400NFT: tokenId does not exist");

		string memory baseURI = _baseUri;
		return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
	}

	function changeBaseURI(string memory baseUri_) public virtual onlyOwner {
		_baseUri = baseUri_;
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
}
