//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1594TestStorage } from "../setup/ERC1594TestStorage.sol";
import { ERC1594 } from "../../src/ERC1594/ERC1594.sol";
import { SigUtils } from "../utils/SigUtils.sol";

abstract contract ERC1594BaseTest is ERC1594TestStorage {
    function setUp() public {
        mockERC1594 = new ERC1594(
            TOKEN_NAME, TOKEN_SYMBOL, TOKEN_VERSION, tokenAdmin, tokenIssuer, tokenRedeemer, tokenTransferAgent
        );

        sigUtilsContract = new SigUtils(mockERC1594.domainSeparator(), mockERC1594.ERC1594_DATA_VALIDATION_HASH());

        vm.startPrank(tokenIssuer);
        mockERC1594.issue(alice, ALICE_INITIAL_BALANCE, "");
        mockERC1594.issue(bob, BOB_INITIAL_BALANCE, "");
        vm.stopPrank();
    }
}
