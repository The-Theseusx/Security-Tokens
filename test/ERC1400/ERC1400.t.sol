//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { ERC1400 } from "../../src/ERC1400/ERC1400.sol";

contract ERC1400Test is Test {
	string public constant TOKEN_NAME = "ERC1400MockToken";
	string public constant TOKEN_SYMBOL = "ERC1400MT";
	string public constant TOKEN_VERSION = "1";

	address public constant ZERO_ADDRESS = address(0);
	address public constant TOKEN_ADMIN = address(0x100);
	address public constant TOKEN_ISSUER = address(0x200);
	address public constant TOKEN_REDEEMER = address(0x300);
	address public constant TOKEN_TRANSFER_AGENT = address(0x400);
	address public constant ALICE = address(0xA11cE);
	address public constant BOB = address(0xb0B);

	bytes32 public constant DEFAULT_PARTITION = bytes32(0);

	//solhint-disable-next-line var-name-mixedcase
	ERC1400 public ERC1400MockToken;

	function setUp() public {
		ERC1400MockToken = new ERC1400(
			TOKEN_NAME,
			TOKEN_SYMBOL,
			TOKEN_VERSION,
			TOKEN_ADMIN,
			TOKEN_ISSUER,
			TOKEN_REDEEMER,
			TOKEN_TRANSFER_AGENT
		);
	}

	function testItHasAName() public {
		string memory name = ERC1400MockToken.name();
		assertEq(name, TOKEN_NAME, "token name is not correct");
	}

	function testItHasASymbol() public {
		string memory symbol = ERC1400MockToken.symbol();
		assertEq(symbol, TOKEN_SYMBOL, "token symbol is not correct");
	}

	function testItHas18Decimals() public {
		uint8 decimals = ERC1400MockToken.decimals();
		assertEq(decimals, uint8(18), "token decimals is not correct");
	}

	function testFailWhenIssuingNotByIssuer() public {
		ERC1400MockToken.issue(ALICE, 100e18, "");
	}

	function testFailWhenIssuingToZeroAddress() public {
		ERC1400MockToken.issue(ZERO_ADDRESS, 100e18, "");
	}

	function testFailWhenIssuingZeroAmount() public {
		ERC1400MockToken.issue(ALICE, 0, "");
	}

	function testIssueTokensByIssuer() public {
		vm.startPrank(TOKEN_ISSUER);

		ERC1400MockToken.issue(ALICE, 100e18, "");
		uint256 balance = ERC1400MockToken.balanceOf(ALICE);
		assertEq(balance, 100e18, "Alice's balance is not correct");
		assertEq(ERC1400MockToken.totalSupply(), 100e18, "total supply is not correct");
		// assertEq(
		// 	ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, ALICE),
		// 	100e18,
		// 	"Alice's balance is not correct"
		// );
		assertEq(ERC1400MockToken.totalSupplyByPartition(DEFAULT_PARTITION), 100e18, "total supply is not correct");

		vm.stopPrank();
	}
}
