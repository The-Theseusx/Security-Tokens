//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { ERC1400 } from "../../src/ERC1400/ERC1400.sol";
import { ERC1400TestStorage } from "./utils/ERC1400TestStorage.sol";
import { ERC1400IssuanceTest } from "./ERC1400Issuance.t.sol";
import { ERC1400RedemptionTest } from "./ERC1400Redemption.t.sol";

contract ERC1400Test is Test, ERC1400TestStorage, ERC1400IssuanceTest, ERC1400RedemptionTest {
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

		vm.startPrank(TOKEN_ISSUER);
		issueTokens(DEFAULT_PARTITION, OWNER, INITIAL_SUPPLY, "");
		vm.stopPrank();
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
}
