//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { ERC1400 } from "../../src/ERC1400/ERC1400.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract ERC1400Test is Test {
	using Strings for uint256;

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

	bytes32 public constant DEFAULT_PARTITION = bytes32(0);
	bytes32 public constant SHARED_SPACES_PARTITION = keccak256("CONDOMINIUM_SHARED_SPACES");

	// Issuance / Redemption Events
	event Issued(address indexed operator, address indexed to, uint256 amount, bytes data);
	event IssuedByPartition(bytes32 indexed partition, address indexed to, uint256 amount, bytes data);
	event Redeemed(address indexed operator, address indexed from, uint256 amount, bytes data);

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

	function testShouldNotIssueToZeroAddress() public {
		vm.startPrank(TOKEN_ISSUER);
		vm.expectRevert("ERC1400: Invalid recipient (zero address)");
		ERC1400MockToken.issue(ZERO_ADDRESS, 100e18, "");
		vm.stopPrank();
	}

	function testShouldNotIssueZeroAmount() public {
		vm.startPrank(TOKEN_ISSUER);
		vm.expectRevert("ERC1400: zero amount");
		ERC1400MockToken.issue(ALICE, 0, "");
		vm.stopPrank();
	}

	function testIssueTokensByIssuer() public {
		vm.startPrank(TOKEN_ISSUER);

		///@dev check the Issued event is emitted
		vm.expectEmit(true, true, true, true);
		emit Issued(TOKEN_ISSUER, ALICE, 100e18, "");

		ERC1400MockToken.issue(ALICE, 100e18, "");

		assertEq(ERC1400MockToken.balanceOf(ALICE), 100e18, "Alice's total balance should be 100e18");
		assertEq(ERC1400MockToken.totalSupply(), 100e18, "token total supply should be 100e18");
		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, ALICE),
			100e18,
			"Alice's default partition balance should be 100e18"
		);
		assertEq(
			ERC1400MockToken.totalSupplyByPartition(DEFAULT_PARTITION),
			100e18,
			"token default partition total supply should be 100e18"
		);

		vm.stopPrank();
	}

	function testIssueTokenByPartitionByIssuer() public {
		vm.startPrank(TOKEN_ISSUER);

		vm.expectEmit(true, true, true, true);
		emit IssuedByPartition(SHARED_SPACES_PARTITION, BOB, 150e18, "");

		ERC1400MockToken.issueByPartition(SHARED_SPACES_PARTITION, BOB, 150e18, "");

		assertEq(ERC1400MockToken.balanceOf(BOB), 150e18, "Bob's balance should be 150e18 tokens");
		assertEq(ERC1400MockToken.totalSupply(), 150e18, "token total supply should be 100e18");
		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, BOB),
			0,
			"Bob's default partition balance should be 0"
		);
		assertEq(
			ERC1400MockToken.balanceOfByPartition(SHARED_SPACES_PARTITION, BOB),
			150e18,
			"Bob's shared space partition balance should be 150e18"
		);
		assertEq(
			ERC1400MockToken.totalSupplyByPartition(DEFAULT_PARTITION),
			0,
			"token default partition total supply should be 0"
		);
		assertEq(
			ERC1400MockToken.totalSupplyByPartition(SHARED_SPACES_PARTITION),
			150e18,
			"token default partition total supply should be 150e18"
		);

		bytes32[] memory bobPartitions = ERC1400MockToken.partitionsOf(BOB);
		assertEq(
			bobPartitions[0],
			SHARED_SPACES_PARTITION,
			"Bob's first partition should be keccack256(SHARED_SPACES_PARTITION)"
		);

		assertEq(ERC1400MockToken.totalPartitions(), 1, "Token should have a total of 1 paritions");

		vm.stopPrank();
	}
}
