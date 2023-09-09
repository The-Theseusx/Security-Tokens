//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { ERC1400 } from "../../src/ERC1400/ERC1400.sol";

abstract contract ERC1400BehaviorTest is Test {
	string public constant TOKEN_NAME = "ERC1400MockToken";
	string public constant TOKEN_SYMBOL = "ERC1400MT";
	string public constant TOKEN_VERSION = "1";
	address public constant ZERO_ADDRESS = address(0);
	address public constant TOKEN_ADMIN = address(0x100);
	address public constant TOKEN_ISSUER = address(0x200);
	address public constant TOKEN_REDEEMER = address(0x300);
	address public constant TOKEN_TRANSFER_AGENT = address(0x400);

	//solhint-disable-next-line var-name-mixedcase
	ERC1400 public ERC1400MockToken;

	constructor(ERC1400 _ERC1400MockToken) {
		ERC1400MockToken = _ERC1400MockToken;
	}
	// function setUp() public {
	// 	ERC1400MockToken = new ERC1400(
	// 		TOKEN_NAME,
	// 		TOKEN_SYMBOL,
	// 		TOKEN_VERSION,
	// 		TOKEN_ADMIN,
	// 		TOKEN_ISSUER,
	// 		TOKEN_REDEEMER,
	// 		TOKEN_TRANSFER_AGENT
	// 	);
	// }

	// function shouldBehaveLikeERC1400() public {}
}
