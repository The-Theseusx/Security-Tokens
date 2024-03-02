//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1594 } from "../../src/ERC1594/ERC1594.sol";
import { BaseTestStorage } from "./BaseTestStorage.t.sol";

abstract contract ERC1594TestStorage is BaseTestStorage {
    ERC1594 public mockERC1594;
}
