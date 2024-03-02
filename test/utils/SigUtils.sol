// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1400ValidateDataParams, ERC1400NFTValidateDataParams } from "../../src/utils/DataTypes.sol";

//solhint-disable immutable-vars-naming
contract SigUtils {
    bytes32 internal immutable _domainSeparator;
    ///@dev EIP712 domain separator.
    bytes32 internal immutable _msgTypeHash;
    ///@dev eg keccak256("ValidateData(address from,address to,uint256 amount,bytes32 data)");

    constructor(bytes32 domainSeparator, bytes32 msgTypeHash) {
        _domainSeparator = domainSeparator;
        _msgTypeHash = msgTypeHash;
    }

    ///@dev computes the hash of a ERC1400 data validation struct
    function _getERC1400StructHash(
        ERC1400ValidateDataParams memory _validateDataParams,
        uint256 _nonce,
        uint48 _deadline
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _msgTypeHash,
                _validateDataParams.from,
                _validateDataParams.to,
                _validateDataParams.amount,
                _validateDataParams.partition,
                _nonce,
                _deadline
            )
        );
    }

    ///@dev computes the hash of a ERC1400NFT data validation struct
    function _getERC1400NFTStructHash(
        ERC1400NFTValidateDataParams memory _validateDataParams,
        uint256 _nonce,
        uint48 _deadline
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _msgTypeHash,
                _validateDataParams.from,
                _validateDataParams.to,
                _validateDataParams.tokenId,
                _validateDataParams.partition,
                _nonce,
                _deadline
            )
        );
    }

    ///@dev computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getERC1400TypedDataHash(
        ERC1400ValidateDataParams memory _validateDataParams,
        uint256 nonce,
        uint48 deadline
    ) public view returns (bytes32) {
        return keccak256(
            abi.encodePacked("\x19\x01", _domainSeparator, _getERC1400StructHash(_validateDataParams, nonce, deadline))
        );
    }

    ///@dev computes the hash of the fully encoded EIP-712 message for the domain of ERC1400NFT token, which can be used to recover the signer
    function getERC1400NFTTypedDataHash(
        ERC1400NFTValidateDataParams memory _validateDataParams,
        uint256 nonce,
        uint48 deadline
    ) public view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01", _domainSeparator, _getERC1400NFTStructHash(_validateDataParams, nonce, deadline)
            )
        );
    }

    //############################################################# ERC1594 SigUtils ##################################################################
    ///@dev computes the hash of a ERC1594 data validation struct
    function _getERC1594StructHash(address from, address to, uint256 amount, uint256 _nonce, uint48 _deadline)
        internal
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(_msgTypeHash, from, to, amount, _nonce, _deadline));
    }

    ///@dev computes the hash of a ERC1594NFT data validation struct
    function _getERC1594NFTStructHash(address from, address to, uint256 tokenId, uint256 _nonce, uint48 _deadline)
        internal
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(_msgTypeHash, from, to, tokenId, _nonce, _deadline));
    }

    ///@dev computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getERC1594TypedDataHash(address from, address to, uint256 amount, uint256 nonce, uint48 deadline)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked("\x19\x01", _domainSeparator, _getERC1594StructHash(from, to, amount, nonce, deadline))
        );
    }

    ///@dev computes the hash of the fully encoded EIP-712 message for the domain of ERC1594NFT token, which can be used to recover the signer
    function getERC1594NFTTypedDataHash(address from, address to, uint256 tokenId, uint256 nonce, uint48 deadline)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked("\x19\x01", _domainSeparator, _getERC1594NFTStructHash(from, to, tokenId, nonce, deadline))
        );
    }
}
