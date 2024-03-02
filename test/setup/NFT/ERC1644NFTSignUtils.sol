//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1644NFTTestStorage } from "./ERC1644NFTTestStorage.sol";

abstract contract ERC1644NFTSigUtils is ERC1644NFTTestStorage {
    struct PrepareSignatureParams {
        uint256 signerPk;
        bytes32 authorizerRole;
        address from;
        address to;
        uint256 tokenId;
        uint256 nonce;
        uint48 deadline;
    }

    function prepareTransferSignature(
        uint256 signerPk,
        address from,
        address to,
        uint256 tokenId,
        uint256 nonce,
        uint48 deadline
    ) public returns (bytes memory) {
        bytes32 role = mockERC1644NFT.ERC1594NFT_TRANSFER_AGENT_ROLE();
        nonce = nonce == 0 ? mockERC1644NFT.getRoleNonce(role) : nonce;
        deadline = deadline == 0 ? uint48(block.timestamp + 1 minutes) : deadline;

        PrepareSignatureParams memory sigParams = PrepareSignatureParams({
            signerPk: signerPk,
            authorizerRole: role,
            from: from,
            to: to,
            tokenId: tokenId,
            nonce: nonce,
            deadline: deadline
        });

        return _prepareSignature(sigParams);
    }

    function prepareRedemptionSignature(uint256 signerPk, address from, uint256 tokenId, uint256 nonce, uint48 deadline)
        public
        returns (bytes memory)
    {
        bytes32 role = mockERC1644NFT.ERC1594NFT_REDEEMER_ROLE();
        nonce = nonce == 0 ? mockERC1644NFT.getRoleNonce(role) : nonce;
        deadline = deadline == 0 ? uint48(block.timestamp + 1 minutes) : deadline;

        PrepareSignatureParams memory sigParams = PrepareSignatureParams({
            signerPk: signerPk,
            authorizerRole: role,
            from: from,
            to: address(0),
            tokenId: tokenId,
            nonce: nonce,
            deadline: deadline
        });

        return _prepareSignature(sigParams);
    }

    function _prepareSignature(PrepareSignatureParams memory _sigParams) internal returns (bytes memory) {
        ///@dev data field in ERC1400ValidateDataParams not needed in this step hence "" is used
        bytes32 structMessage = sigUtilsContract.getERC1594NFTTypedDataHash(
            _sigParams.from, _sigParams.to, _sigParams.tokenId, _sigParams.nonce, _sigParams.deadline
        );

        address signer = vm.addr(_sigParams.signerPk);

        vm.startPrank(signer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_sigParams.signerPk, structMessage);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.stopPrank();

        return abi.encode(signature, _sigParams.deadline);
    }
}
