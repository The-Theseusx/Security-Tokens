//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC721 } from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { IERC1594NFT } from "./IERC1594NFT.sol";
import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { EIP712 } from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract ERC1594NFT is IERC1594NFT, ERC721, EIP712, AccessControl {
    /// @dev EIP712 typehash for data validation
    bytes32 public constant ERC1594NFT_DATA_VALIDATION_HASH =
        keccak256("ERC1594NFTValidateData(address from,address to,uint256 tokenId,uint256 nonce,uint48 deadline)");

    ///@dev Access control role for token admin.
    bytes32 public constant ERC1594NFT_ADMIN_ROLE = keccak256("ERC1594NFT_ADMIN_ROLE");

    ///@dev Access control role for the token issuer.
    bytes32 public constant ERC1594NFT_ISSUER_ROLE = keccak256("ERC1594NFT_ISSUER_ROLE");

    ///@dev Access control role for the token redeemer.
    bytes32 public constant ERC1594NFT_REDEEMER_ROLE = keccak256("ERC1594NFT_REDEEMER_ROLE");

    ///@dev Access control role for the token transfer agent. Transfer agents can authorize transfers with their signatures.
    bytes32 public constant ERC1594NFT_TRANSFER_AGENT_ROLE = keccak256("ERC1594NFT_TRANSFER_AGENT_ROLE");

    ///  @dev should track if token is issuable or not. Should not be modifiable if false.
    bool private _isIssuable;

    mapping(bytes32 => uint256) private _roleNonce;

    /// @dev event emitted when tokens are transferred with data attached
    event TransferWithData(address indexed from, address indexed to, uint256 tokenId, bytes data);

    /// @dev event emitted when issuance is disabled
    event IssuanceDisabled();

    event NonceSpent(bytes32 indexed role, address indexed spender, uint256 nonceSpent);

    error ERC1594NFT_IssuanceDisabled();
    error ERC1594NFT_InvalidAddress(address addr);
    error ERC1594NFT_InvalidReceiver(address receiver);
    error ERC1594NFT_NotTokenOwner();
    error ERC1594NFT_InvalidData();
    error ERC1594NFT_InvalidSignatureData();

    constructor(
        string memory name_,
        string memory symbol_,
        string memory version_,
        address tokenAdmin,
        address tokenIssuer,
        address tokenRedeemer,
        address tokenTransferAgent
    ) ERC721(name_, symbol_) EIP712(name_, version_) {
        _setRoleAdmin(ERC1594NFT_ADMIN_ROLE, ERC1594NFT_ADMIN_ROLE);
        _setRoleAdmin(ERC1594NFT_ISSUER_ROLE, ERC1594NFT_ADMIN_ROLE);
        _setRoleAdmin(ERC1594NFT_REDEEMER_ROLE, ERC1594NFT_ADMIN_ROLE);
        _setRoleAdmin(ERC1594NFT_TRANSFER_AGENT_ROLE, ERC1594NFT_ADMIN_ROLE);
        _grantRole(ERC1594NFT_ADMIN_ROLE, tokenAdmin);
        _grantRole(ERC1594NFT_ISSUER_ROLE, tokenIssuer);
        _grantRole(ERC1594NFT_REDEEMER_ROLE, tokenRedeemer);
        _grantRole(ERC1594NFT_TRANSFER_AGENT_ROLE, tokenTransferAgent);
        _isIssuable = true;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return interfaceId == type(IERC1594NFT).interfaceId || super.supportsInterface(interfaceId);
    }

    function isIssuable() public view virtual override returns (bool) {
        return _isIssuable;
    }

    /// @return the nonce of a role.
    function getRoleNonce(bytes32 role) public view virtual returns (uint256) {
        return _roleNonce[role];
    }

    function canTransfer(address to, uint256 tokenId, bytes calldata data)
        public
        view
        virtual
        override
        returns (bool, bytes memory, bytes32)
    {
        if (_ownerOf(tokenId) != _msgSender()) return (false, bytes("0x52"), bytes32(0));
        if (to == address(0)) return (false, bytes("0x57"), bytes32(0));
        if (data.length != 0) {
            (bool can,) = _validateData(ERC1594NFT_TRANSFER_AGENT_ROLE, _msgSender(), to, tokenId, data);
            if (!can) return (false, bytes("0x57"), bytes32(0));
        }
        return (true, bytes("0x51"), bytes32(0));
    }

    function canTransferFrom(address from, address to, uint256 tokenId, bytes calldata data)
        public
        view
        virtual
        override
        returns (bool, bytes memory, bytes32)
    {
        if (_ownerOf(tokenId) != from) return (false, bytes("0x52"), bytes32(0));
        if (!_isAuthorized(from, _msgSender(), tokenId)) return (false, bytes("0x52"), bytes32(0));
        if (to == address(0)) return (false, bytes("0x57"), bytes32(0));
        if (data.length != 0) {
            (bool can,) = _validateData(ERC1594NFT_TRANSFER_AGENT_ROLE, from, to, tokenId, data);
            if (!can) return (false, bytes("0x57"), bytes32(0));
        }
        return (true, bytes("0x51"), bytes32(0));
    }

    /// @dev issue tokens to a recipient
    function issue(address to, uint256 tokenId, bytes calldata data)
        public
        virtual
        override
        onlyRole(ERC1594NFT_ISSUER_ROLE)
    {
        if (!_isIssuable) revert ERC1594NFT_IssuanceDisabled();
        if (to == address(0)) revert ERC1594NFT_InvalidAddress(to);
        if (_ownerOf(tokenId) != address(0)) revert ERC1594NFT_InvalidReceiver(to);

        _issue(to, tokenId, data);
    }

    /// @dev See {IERC1594-redeem}.
    function redeem(uint256 tokenId, bytes calldata data) public virtual override {
        if (_ownerOf(tokenId) != _msgSender() && data.length == 0) revert ERC1594NFT_NotTokenOwner();
        _redeem(_msgSender(), tokenId, data);
    }

    function redeemFrom(address from, uint256 tokenId, bytes calldata data)
        public
        virtual
        override
        onlyRole(ERC1594NFT_REDEEMER_ROLE)
    {
        if (from == address(0)) revert ERC1594NFT_InvalidAddress(from);
        if (_ownerOf(tokenId) != from) revert ERC1594NFT_NotTokenOwner();

        _redeem(from, tokenId, data);
    }

    /// @dev issues tokens to a recipient
    function _issue(address to, uint256 tokenId, bytes calldata data) internal virtual {
        _mint(to, tokenId);
        emit Issued(_msgSender(), to, tokenId, data);
    }

    /**
     * @dev burns tokens from a recipient
     */
    function _redeem(address from, uint256 tokenId, bytes calldata data) internal virtual {
        if (data.length != 0 && !hasRole(ERC1594NFT_REDEEMER_ROLE, _msgSender())) {
            (bool authorized, address authorizer) =
                _validateData(ERC1594NFT_REDEEMER_ROLE, from, address(0), tokenId, data);
            if (!authorized) revert ERC1594NFT_InvalidSignatureData();
            _spendNonce(ERC1594NFT_REDEEMER_ROLE, authorizer);
        }
        _burn(tokenId);
        emit Redeemed(_msgSender(), from, tokenId, data);
    }

    function transferWithData(address to, uint256 tokenId, bytes calldata data) public virtual override {
        if (to == address(0)) revert ERC1594NFT_InvalidReceiver(to);
        if (_ownerOf(tokenId) != _msgSender()) revert ERC1594NFT_NotTokenOwner();
        if (data.length == 0) revert ERC1594NFT_InvalidData();

        _transferWithData(_msgSender(), to, tokenId, data);
    }

    function transferFromWithData(address from, address to, uint256 tokenId, bytes calldata data)
        public
        virtual
        override
    {
        if (from == address(0)) revert ERC1594NFT_InvalidAddress(from);
        if (to == address(0)) revert ERC1594NFT_InvalidReceiver(to);
        if (data.length == 0) revert ERC1594NFT_InvalidData();

        _transferWithData(from, to, tokenId, data);
    }

    /// @dev transfers tokens from a sender to a recipient with data
    function _transferWithData(address from, address to, uint256 tokenId, bytes calldata data) internal virtual {
        (bool authorized, address authorizer) = _validateData(ERC1594NFT_TRANSFER_AGENT_ROLE, from, to, tokenId, data);
        if (!authorized) revert ERC1594NFT_InvalidSignatureData();
        _spendNonce(ERC1594NFT_TRANSFER_AGENT_ROLE, authorizer);
        _transfer(from, to, tokenId);
        emit TransferWithData(_msgSender(), to, tokenId, data);
    }

    /**
     * @dev returns true if recovered signer is the authorized body
     * @param from address of the owner or authorized body
     * @param to address of the receiver
     * @param tokenId tokenId of tokens
     * @param data data parameter
     */
    function _validateData(bytes32 authorizerRole, address from, address to, uint256 tokenId, bytes calldata data)
        internal
        view
        virtual
        returns (bool, address authorizer)
    {
        (bytes memory signature, uint48 deadline) = abi.decode(data, (bytes, uint48));

        bytes32 authorizerRole_ = authorizerRole;
        bytes32 structData = keccak256(
            abi.encode(ERC1594NFT_DATA_VALIDATION_HASH, from, to, tokenId, _roleNonce[authorizerRole_], deadline)
        );
        address recoveredSigner = ECDSA.recover(_hashTypedDataV4(structData), signature);

        return (hasRole(authorizerRole_, recoveredSigner), recoveredSigner);
    }

    /// @dev disables issuance of tokens, can only be called by the owner
    function disableIssuance() public virtual {
        _isIssuable = false;
        emit IssuanceDisabled();
    }

    /**
     * @param role the role for which the nonce is increased
     * @param spender the address that spent the nonce in a signature
     */
    function _spendNonce(bytes32 role, address spender) private {
        uint256 nonce = ++_roleNonce[role];
        emit NonceSpent(role, spender, nonce - 1);
    }
}
