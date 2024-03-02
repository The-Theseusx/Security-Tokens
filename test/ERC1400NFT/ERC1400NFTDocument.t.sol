//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC1400NFTBaseTest} from "./ERC1400NFTBaseTest.t.sol";

contract ERC1400NFTDocumentTest is ERC1400NFTBaseTest {
    bytes32 public documentName = "Asset5Data";
    string public documentURI = "https://offchain.example.com/document/5";
    bytes32 public documentHash = keccak256(bytes(documentURI));

    function testSetDocumentFailsWhenCallerNotAdmin() public {
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, alice, ERC1400NFTMockToken.ERC1400_NFT_ADMIN_ROLE()
            )
        );
        ERC1400NFTMockToken.setDocument(documentName, documentURI, documentHash);
        vm.stopPrank();
    }

    function testSetDocument() public {
        vm.startPrank(tokenAdmin);
        vm.expectEmit(true, true, true, true);
        emit DocumentUpdated(documentName, documentURI, documentHash);

        uint256 setTime = block.timestamp;
        ERC1400NFTMockToken.setDocument(documentName, documentURI, documentHash);
        vm.stopPrank();

        skip(5 hours);
        (string memory docUri, bytes32 docHash, uint256 lastUpdated) = ERC1400NFTMockToken.getDocument(documentName);

        assertEq(docUri, documentURI, "documentURI should be equal to docUri");
        assertEq(docHash, documentHash, "documentHash should be equal to docHash");
        assertEq(lastUpdated, setTime, "lastUpdated should be equal to setTime");
    }

    function testRemoveDocumentFailsWhenCallerNotAdmin() public {
        vm.startPrank(tokenAdmin);
        ERC1400NFTMockToken.setDocument(documentName, documentURI, documentHash);
        vm.stopPrank();

        vm.startPrank(notTokenAdmin);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, notTokenAdmin, ERC1400NFTMockToken.ERC1400_NFT_ADMIN_ROLE()
            )
        );
        ERC1400NFTMockToken.removeDocument(documentName);
        vm.stopPrank();
    }

    function testRemoveDocument() public {
        vm.startPrank(tokenAdmin);
        ERC1400NFTMockToken.setDocument(documentName, documentURI, documentHash);

        skip(5 minutes);

        vm.expectEmit(true, true, true, true);
        emit DocumentRemoved(documentName, documentURI, documentHash);
        ERC1400NFTMockToken.removeDocument(documentName);
        vm.stopPrank();

        skip(5 hours);

        (string memory docUri, bytes32 docHash, uint256 lastUpdated) = ERC1400NFTMockToken.getDocument(documentName);

        assertEq(docUri, "", "docUri should be empty");
        assertEq(docHash, bytes32(0), "docHash should be empty");
        assertEq(lastUpdated, 0, "lastUpdated should be 0");
    }

    function testGetAllDocuments() public {
        bytes32[] memory allDocs = ERC1400NFTMockToken.getAllDocuments();

        assertEq(allDocs.length, 0, "allDocs should be empty");

        vm.startPrank(tokenAdmin);
        ERC1400NFTMockToken.setDocument(documentName, documentURI, documentHash);

        skip(5 minutes);

        ERC1400NFTMockToken.setDocument("Asset6", "https://example.com", keccak256("https://example.com"));
        vm.stopPrank();

        allDocs = ERC1400NFTMockToken.getAllDocuments();

        assertEq(allDocs.length, 2, "allDocs should have 2 documents");

        assertEq(allDocs[0], documentName, "allDocs[0] should be equal to documentName");
        assertEq(allDocs[1], "Asset6", "allDocs[1] should be equal to Asset6");
    }
}
