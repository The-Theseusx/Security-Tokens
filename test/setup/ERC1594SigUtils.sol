//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1594TestStorage } from "./ERC1594TestStorage.sol";

abstract contract ERC1594SigUtils is ERC1594TestStorage {
    struct PrepareSignatureParams {
        uint256 signerPk;
        bytes32 authorizerRole;
        address from;
        address to;
        uint256 amount;
        uint256 nonce;
        uint48 deadline;
    }

    function prepareTransferSignature(
        uint256 signerPk,
        address from,
        address to,
        uint256 amount,
        uint256 nonce,
        uint48 deadline
    ) public returns (bytes memory) {
        bytes32 role = mockERC1594.ERC1594_TRANSFER_AGENT_ROLE();
        nonce = nonce == 0 ? mockERC1594.getRoleNonce(role) : nonce;
        deadline = deadline == 0 ? uint48(block.timestamp + 1 minutes) : deadline;

        PrepareSignatureParams memory sigParams = PrepareSignatureParams({
            signerPk: signerPk,
            authorizerRole: role,
            from: from,
            to: to,
            amount: amount,
            nonce: nonce,
            deadline: deadline
        });

        return _prepareSignature(sigParams);
    }

    function prepareRedemptionSignature(uint256 signerPk, address from, uint256 amount, uint256 nonce, uint48 deadline)
        public
        returns (bytes memory)
    {
        bytes32 role = mockERC1594.ERC1594_REDEEMER_ROLE();
        nonce = nonce == 0 ? mockERC1594.getRoleNonce(role) : nonce;
        deadline = deadline == 0 ? uint48(block.timestamp + 1 minutes) : deadline;

        PrepareSignatureParams memory sigParams = PrepareSignatureParams({
            signerPk: signerPk,
            authorizerRole: role,
            from: from,
            to: address(0),
            amount: amount,
            nonce: nonce,
            deadline: deadline
        });

        return _prepareSignature(sigParams);
    }

    function _prepareSignature(PrepareSignatureParams memory _sigParams) internal returns (bytes memory) {
        bytes32 structMessage = sigUtilsContract.getERC1594TypedDataHash(
            _sigParams.from, _sigParams.to, _sigParams.amount, _sigParams.nonce, _sigParams.deadline
        );

        address signer = vm.addr(_sigParams.signerPk);

        vm.startPrank(signer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_sigParams.signerPk, structMessage);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.stopPrank();

        return abi.encode(signature, _sigParams.deadline);
    }
}
