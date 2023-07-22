//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev ERC1400 compatible with ERC721 for non-fungible security tokens.
 * @dev Each token Id must be unique irrespective of partition.
 * @dev A token id issued to the default partition cannot be issued to any other partition.
 */
contract ERC1400NFT {
	///@dev Default token partition
	bytes32 public constant DEFAULT_PARTITION = bytes32(0);

	///@dev token name
	string private _name;

	///@dev token symbol
	string private _symbol;

	///@dev token contract version for EIP712
	string private _version;

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

	constructor(string memory name_, string memory symbol_, string memory version_) {
		_name = name_;
		_symbol = symbol_;
		_version = version_;
		_isIssuable = true;
	}

	function tokenDetails(uint256 tokenId) public pure virtual returns (string memory) {
		return string(abi.encodePacked("tokenId:", tokenId));
	}
}
