//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { SigUtils } from "../utils/SigUtils.sol";

abstract contract BaseTestStorage is Test {
    uint256 public constant TOKEN_ADMIN_PK = 0x100;
    uint256 public constant NOT_ADMIN_PK = 0x419;
    uint256 public constant TOKEN_ISSUER_PK = 0x200;
    uint256 public constant TOKEN_REDEEMER_PK = 0x300;
    uint256 public constant TOKEN_TRANSFER_AGENT_PK = 0x400;
    uint256 public constant ALICE_PK = 0xA11cE;
    uint256 public constant BOB_PK = 0xB0b;

    uint256 public constant TOKEN_ADMIN_OPERATOR_PK = 0x100093A0;
    uint256 public constant NOT_TOKEN_ADMIN_OPERATOR_PK = 0x419093A0;
    uint256 public constant ALICE_OPERATOR_PK = 0xA11cE093A0;
    uint256 public constant BOB_OPERATOR_PK = 0xB0b093A0;

    address public constant ZERO_ADDRESS = address(0);

    address public tokenAdmin = vm.addr(TOKEN_ADMIN_PK);
    address public notTokenAdmin = vm.addr(NOT_ADMIN_PK);
    address public tokenIssuer = vm.addr(TOKEN_ISSUER_PK);
    address public tokenRedeemer = vm.addr(TOKEN_REDEEMER_PK);
    address public tokenTransferAgent = vm.addr(TOKEN_TRANSFER_AGENT_PK);
    address public alice = vm.addr(ALICE_PK);
    address public bob = vm.addr(BOB_PK);

    SigUtils public sigUtilsContract;

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
}
