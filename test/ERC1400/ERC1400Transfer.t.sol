//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import { Test } from "forge-std/Test.sol";
import { ERC1400 } from "../../src/ERC1400/ERC1400.sol";
import { ERC1400BaseTest } from "./ERC1400BaseTest.t.sol";

abstract contract ERC1400TransferTest is ERC1400BaseTest {
	function testTransferTokensOnDefaultPartition() public {
		uint256 tokenAdminBalancePrior = ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, tokenAdmin);

		vm.startPrank(tokenAdmin);
		vm.expectEmit(true, true, true, true);
		emit Transfer(tokenAdmin, bob, 1000e18);
		ERC1400MockToken.transfer(bob, 1000e18);
		vm.stopPrank();

		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, bob),
			1000e18,
			"Bob's default partition balance should be 1000e18"
		);
		assertEq(
			ERC1400MockToken.balanceOfByPartition(DEFAULT_PARTITION, tokenAdmin),
			tokenAdminBalancePrior - 1000e18,
			"Admin's balance should reduce by 1000e18"
		);
	}
}
