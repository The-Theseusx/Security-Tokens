//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1400 } from "../../../src/ERC1400/ERC1400.sol";

abstract contract ERC1400TestStorage {
	string public constant TOKEN_NAME = "ERC1400MockToken";
	string public constant TOKEN_SYMBOL = "ERC1400MTK";
	string public constant TOKEN_VERSION = "1";

	address public constant ZERO_ADDRESS = address(0);
	address public constant TOKEN_ADMIN = address(0x100);
	address public constant TOKEN_ISSUER = address(0x200);
	address public constant TOKEN_REDEEMER = address(0x300);
	address public constant TOKEN_TRANSFER_AGENT = address(0x400);
	address public constant ALICE = address(0xA11cE);
	address public constant BOB = address(0xb0B);
	address public constant OWNER = address(0xAd01);

	uint256 public constant INITIAL_SUPPLY = 100_000_000e18;

	bytes32 public constant DEFAULT_PARTITION = bytes32(0);
	bytes32 public constant SHARED_SPACES_PARTITION = keccak256("CONDOMINIUM_SHARED_SPACES");

	//solhint-disable-next-line var-name-mixedcase
	ERC1400 public ERC1400MockToken;

	// Issuance / Redemption Events
	event Issued(address indexed operator, address indexed to, uint256 amount, bytes data);
	event IssuedByPartition(bytes32 indexed partition, address indexed to, uint256 amount, bytes data);
	event Redeemed(address indexed operator, address indexed from, uint256 amount, bytes data);
}
