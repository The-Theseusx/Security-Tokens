//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseTestStorage } from "./BaseTestStorage.t.sol";
import { ERC1644 } from "../../src/ERC1644/ERC1644.sol";

abstract contract ERC1644TestStorage is BaseTestStorage {
    uint256 public constant TOKEN_CONTROLLER_1_PK = 0x1034C04101;
    uint256 public constant TOKEN_CONTROLLER_2_PK = 0x1034C04102;
    uint256 public constant TOKEN_CONTROLLER_3_PK = 0x1034C04103;

    address public tokenController1 = vm.addr(TOKEN_CONTROLLER_1_PK);
    address public tokenController2 = vm.addr(TOKEN_CONTROLLER_2_PK);
    address public tokenController3 = vm.addr(TOKEN_CONTROLLER_3_PK);

    ERC1644 public mockERC1644;
}
