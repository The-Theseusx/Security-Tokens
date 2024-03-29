//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { IERC1643 } from "./IERC1643.sol";

/**
 * @title ERC1643
 * @dev ERC1643 support for document management of security tokens
 */
abstract contract ERC1643 is IERC1643, AccessControl {
    bytes32 public immutable ADMIN_ROLE;

    struct Document {
        bytes32 docHash; // Hash of the document
        uint256 lastModified; // Timestamp at which document details was last modified
        string uri; // URI of the document that exist off-chain
    }

    error ERC1643_InvalidDocumentName();
    error ERC1643_InvalidDocumentUri(string uri);
    error ERC1643_NonExistentDocument(bytes32 name);

    constructor(address admin, bytes32 authRole) {
        _grantRole(authRole, admin);
        ADMIN_ROLE = authRole;
    }

    /**
     * @dev array of all document names (stored hashes)
     */
    bytes32[] public allDocumentNames;

    /**
     * @dev all document names indexes in allDocumentNames array, for quick and efficient search
     */
    mapping(bytes32 => uint256) public documentIndex;

    /**
     * @dev mapping of the document name to the document content.
     */
    mapping(bytes32 => Document) public documents;

    /**
     * @dev Sets document details for a given document name.
     * @param name Name of the document.
     * @param uri Document content.
     * @param documentHash Hash of the document [optional parameter].
     */
    function setDocument(bytes32 name, string memory uri, bytes32 documentHash)
        public
        virtual
        override
        onlyRole(ADMIN_ROLE)
    {
        if (name == bytes32(0)) revert ERC1643_InvalidDocumentName();
        if (bytes(uri).length == 0) revert ERC1643_InvalidDocumentUri(uri);

        if (documents[name].lastModified == 0) {
            documents[name] = Document(documentHash, block.timestamp, uri);

            documentIndex[name] = allDocumentNames.length;
            allDocumentNames.push(name);
        } else {
            Document memory doc = documents[name];
            doc.lastModified = block.timestamp;
            doc.uri = uri;
            doc.docHash = documentHash;
            documents[name] = doc;
        }

        emit DocumentUpdated(name, uri, documentHash);
    }

    /**
     * @dev Removes document details for a given document name.
     * @param name Name of the document.
     */
    function removeDocument(bytes32 name) public virtual override onlyRole(ADMIN_ROLE) {
        if (name == bytes32(0)) revert ERC1643_InvalidDocumentName();

        Document memory doc = documents[name];
        if (doc.lastModified == 0 || bytes(doc.uri).length == 0) revert ERC1643_NonExistentDocument(name);
        delete documents[name];

        uint256 index = documentIndex[name];
        uint256 lastIndex = allDocumentNames.length - 1;

        if (index != lastIndex) {
            bytes32 lastDocumentName = allDocumentNames[lastIndex];
            allDocumentNames[index] = lastDocumentName;
            documentIndex[lastDocumentName] = index;
        }

        allDocumentNames.pop();
        delete documentIndex[name];

        emit DocumentRemoved(name, doc.uri, doc.docHash);
    }

    /**
     * @dev Returns document details for a given document name.
     * @param name Name of the document.
     * @return string Document content.
     * @return bytes32 Hash of the document [optional parameter].
     * @return uint256 Timestamp when the document was last modified.
     */
    function getDocument(bytes32 name) public view virtual override returns (string memory, bytes32, uint256) {
        Document memory doc = documents[name];
        return (doc.uri, doc.docHash, doc.lastModified);
    }

    /**
     * @dev Returns list of all document names.
     * @return List of all document names.
     */
    function getAllDocuments() public view virtual override returns (bytes32[] memory) {
        return allDocumentNames;
    }

    /**
     * @dev returns all documents
     */
    function getAllDocumentsDetails() public view returns (Document[] memory) {
        uint256 docsLength = allDocumentNames.length;
        Document[] memory docs = new Document[](docsLength);

        uint256 i;
        for (; i < docsLength;) {
            docs[i] = documents[allDocumentNames[i]];

            unchecked {
                ++i;
            }
        }
        return docs;
    }
}
