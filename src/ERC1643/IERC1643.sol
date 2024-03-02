//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC1643 {
    // Document Events
    event DocumentRemoved(bytes32 indexed name, string uri, bytes32 documentHash);
    event DocumentUpdated(bytes32 indexed name, string uri, bytes32 documentHash);

    // Document Management
    function getDocument(bytes32 name) external view returns (string memory, bytes32, uint256);

    function setDocument(bytes32 name, string memory uri, bytes32 documentHash) external;

    function removeDocument(bytes32 name) external;

    function getAllDocuments() external view returns (bytes32[] memory);
}
