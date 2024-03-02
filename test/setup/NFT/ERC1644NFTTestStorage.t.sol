//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1644NFT } from "../../../src/ERC1644/ERC1644NFT/ERC1644NFT.sol";
import { BaseTestNFTStorage } from "./BaseTestNFTStorage.t.sol";

abstract contract ERC1594TestStorage is BaseTestNFTStorage {
    ERC1644NFT public mockERC1644NFT;
}
