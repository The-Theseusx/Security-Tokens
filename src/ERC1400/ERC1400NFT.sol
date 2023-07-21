//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev ERC1400 compatible with ERC721 for non-fungible security tokens
 */
contract ERC1400NFT {
    
    function tokenDetails(uint256 tokenId) public pure virtual returns (string memory) {
        return string(abi.encodePacked("tokenId:", tokenId));
    }
}