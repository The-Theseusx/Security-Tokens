//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1594NFT } from "../../../src/ERC1594/ERC1594NFT/ERC1594NFT.sol";
import { BaseTestNFTStorage } from "./BaseTestNFTStorage.t.sol";

abstract contract ERC1594NFTTestStorage is BaseTestNFTStorage {
    ERC1594NFT public mockERC1594NFT;
}
