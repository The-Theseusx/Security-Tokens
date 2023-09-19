//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { ERC1400 } from "../../../src/ERC1400/ERC1400.sol";
import { SigUtils } from "../../utils/SigUtils.sol";

abstract contract ERC1400TestStorage is Test {
	string public constant TOKEN_NAME = "ERC1400MockToken";
	string public constant TOKEN_SYMBOL = "ERC1400MTK";
	string public constant TOKEN_VERSION = "1";

	uint256 public constant TOKEN_ADMIN_PK = 0x100;
	uint256 public constant NOT_ADMIN_PK = 0x419;
	uint256 public constant TOKEN_ISSUER_PK = 0x200;
	uint256 public constant TOKEN_REDEEMER_PK = 0x300;
	uint256 public constant TOKEN_TRANSFER_AGENT_PK = 0x400;
	uint256 public constant ALICE_PK = 0xA11cE;
	uint256 public constant BOB_PK = 0xB0b;

	address public constant ZERO_ADDRESS = address(0);

	uint256 public constant INITIAL_SUPPLY = 100_000_000e18;

	bytes32 public constant DEFAULT_PARTITION = bytes32(0);
	bytes32 public constant SHARED_SPACES_PARTITION = keccak256("CONDOMINIUM_SHARED_SPACES");
	bytes32 public constant DOMAIN_SEPARATOR = 0x256897f89009cd54240b5755edbdc1612b7c5fb63ae29dbe64277a5dccfa3c4b;

	address public tokenAdmin = vm.addr(TOKEN_ADMIN_PK);
	address public notTokenAdmin = vm.addr(NOT_ADMIN_PK);
	address public tokenIssuer = vm.addr(TOKEN_ISSUER_PK);
	address public tokenRedeemer = vm.addr(TOKEN_REDEEMER_PK);
	address public tokenTransferAgent = vm.addr(TOKEN_TRANSFER_AGENT_PK);
	address public alice = vm.addr(ALICE_PK);
	address public bob = vm.addr(BOB_PK);

	//solhint-disable-next-line var-name-mixedcase
	ERC1400 public ERC1400MockToken;

	SigUtils public sigUtilsContract;

	// Issuance / Redemption Events
	event Issued(address indexed operator, address indexed to, uint256 amount, bytes data);
	event IssuedByPartition(bytes32 indexed partition, address indexed to, uint256 amount, bytes data);
	event Redeemed(address indexed operator, address indexed from, uint256 amount, bytes data);

	event NonceSpent(bytes32 indexed role, address indexed spender, uint256 nonceSpent);
}
