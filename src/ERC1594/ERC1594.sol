//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { IERC1594 } from "./IERC1594.sol";
import { EIP712 } from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title ERC1594
 * @dev ERC1594 core security logic for fungible security tokens
 * @dev Utilizing ERC712 and ECDSA to validate data
 */
contract ERC1594 is IERC1594, ERC20, EIP712, AccessControl {
    /// @dev EIP712 typehash for data validation
    bytes32 public constant ERC1594_DATA_VALIDATION_HASH =
        keccak256("ERC1594ValidateData(address from,address to,uint256 amount,uint256 nonce,uint48 deadline)");

    ///@dev Access control role for token admin.
    bytes32 public constant ERC1594_ADMIN_ROLE = keccak256("ERC1594_ADMIN_ROLE");

    ///@dev Access control role for the token issuer.
    bytes32 public constant ERC1594_ISSUER_ROLE = keccak256("ERC1594_ISSUER_ROLE");

    ///@dev Access control role for the token redeemer.
    bytes32 public constant ERC1594_REDEEMER_ROLE = keccak256("ERC1594_REDEEMER_ROLE");

    ///@dev Access control role for the token transfer agent. Transfer agents can authorize transfers with their signatures.
    bytes32 public constant ERC1594_TRANSFER_AGENT_ROLE = keccak256("ERC1594_TRANSFER_AGENT_ROLE");

    ///  @dev should track if token is issuable or not. Should not be modifiable if false.
    bool private _isIssuable;

    mapping(bytes32 => uint256) private _roleNonce;

    /// @dev event emitted when tokens are transferred with data attached
    event TransferWithData(address indexed from, address indexed to, uint256 amount, bytes data);

    /// @dev event emitted when issuance is disabled
    event IssuanceDisabled();

    event NonceSpent(bytes32 indexed role, address indexed spender, uint256 nonceSpent);

    error ERC1594_IssuanceDisabled();
    error ERC1594_InvalidAddress(address addr);
    error ERC1594_InvalidReceiver(address receiver);
    error ERC1594_ZeroAmount();
    error ERC1594_InvalidData();
    error ERC1594_InvalidSignatureData();

    constructor(
        string memory name_,
        string memory symbol_,
        string memory version_,
        address tokenAdmin,
        address tokenIssuer,
        address tokenRedeemer,
        address tokenTransferAgent
    ) ERC20(name_, symbol_) EIP712(name_, version_) {
        _setRoleAdmin(ERC1594_ADMIN_ROLE, ERC1594_ADMIN_ROLE);
        _setRoleAdmin(ERC1594_ISSUER_ROLE, ERC1594_ADMIN_ROLE);
        _setRoleAdmin(ERC1594_REDEEMER_ROLE, ERC1594_ADMIN_ROLE);
        _setRoleAdmin(ERC1594_TRANSFER_AGENT_ROLE, ERC1594_ADMIN_ROLE);
        _grantRole(ERC1594_ADMIN_ROLE, tokenAdmin);
        _grantRole(ERC1594_ISSUER_ROLE, tokenIssuer);
        _grantRole(ERC1594_REDEEMER_ROLE, tokenRedeemer);
        _grantRole(ERC1594_TRANSFER_AGENT_ROLE, tokenTransferAgent);
        _isIssuable = true;
    }

    function domainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @dev See {IERC1594-isIssuable}.
    function isIssuable() public view virtual override returns (bool) {
        return _isIssuable;
    }

    /// @return the nonce of a role.
    function getRoleNonce(bytes32 role) public view virtual returns (uint256) {
        return _roleNonce[role];
    }

    /// @dev See {IERC1594-issue}.
    function issue(address to, uint256 amount, bytes calldata data)
        public
        virtual
        override
        onlyRole(ERC1594_ISSUER_ROLE)
    {
        if (!_isIssuable) revert ERC1594_IssuanceDisabled();
        if (to == address(0)) revert ERC1594_InvalidReceiver(to);
        if (amount == 0) revert ERC1594_ZeroAmount();

        _issue(to, amount, data);
    }

    /// @dev See {IERC1594-redeem}.
    function redeem(uint256 amount, bytes calldata data) public virtual override {
        if (amount == 0) revert ERC1594_ZeroAmount();

        _redeem(_msgSender(), amount, data);
    }

    /**
     * @dev See {IERC1594-redeemFrom}.
     */
    function redeemFrom(address tokenHolder, uint256 amount, bytes calldata data)
        public
        virtual
        override
        onlyRole(ERC1594_REDEEMER_ROLE)
    {
        if (tokenHolder == address(0)) revert ERC1594_InvalidAddress(tokenHolder);
        if (amount == 0) revert ERC1594_ZeroAmount();

        _redeem(tokenHolder, amount, data);
    }

    /**
     * @dev See {IERC1594-transferWithData}.amount
     */
    function transferWithData(address to, uint256 amount, bytes calldata data) public virtual override {
        if (to == address(0)) revert ERC1594_InvalidReceiver(to);
        if (amount == 0) revert ERC1594_ZeroAmount();
        if (data.length == 0) revert ERC1594_InvalidData();

        _transferWithData(_msgSender(), to, amount, data);
    }

    /// @dev See {IERC1594-transferFromWithData}.
    function transferFromWithData(address from, address to, uint256 amount, bytes calldata data)
        public
        virtual
        override
    {
        if (from == address(0)) revert ERC1594_InvalidAddress(from);
        if (to == address(0)) revert ERC1594_InvalidReceiver(to);
        if (amount == 0) revert ERC1594_ZeroAmount();
        if (data.length == 0) revert ERC1594_InvalidData();

        _transferWithData(from, to, amount, data);
    }

    /**
     * @dev See {IERC1594-canTransfer}.
     */
    function canTransfer(address to, uint256 amount, bytes calldata data)
        public
        view
        virtual
        override
        returns (bool, bytes memory, bytes32)
    {
        if (balanceOf(_msgSender()) < amount) return (false, bytes("0x52"), bytes32(0));
        if (to == address(0)) return (false, bytes("0x57"), bytes32(0));
        if (data.length != 0) {
            (bool can,) = _validateData(ERC1594_TRANSFER_AGENT_ROLE, _msgSender(), to, amount, data);
            if (!can) return (false, bytes("0x57"), bytes32(0));
        }
        return (true, bytes("0x51"), bytes32(0));
    }

    /**
     * @dev See {IERC1594-canTransferFrom}.
     */
    function canTransferFrom(address from, address to, uint256 amount, bytes calldata data)
        public
        view
        virtual
        override
        returns (bool, bytes memory, bytes32)
    {
        if (amount > allowance(from, to)) return (false, bytes("0x53"), bytes32(0));
        if (balanceOf(from) < amount) return (false, bytes("0x52"), bytes32(0));
        if (to == address(0)) return (false, bytes("0x57"), bytes32(0));
        if (data.length != 0) {
            (bool can,) = _validateData(ERC1594_TRANSFER_AGENT_ROLE, from, to, amount, data);
            if (!can) return (false, bytes("0x57"), bytes32(0));
        }
        return (true, bytes("0x51"), bytes32(0));
    }

    /// @dev issues tokens to a recipient
    function _issue(address to, uint256 amount, bytes calldata data) internal virtual {
        _mint(to, amount);
        emit Issued(_msgSender(), to, amount, data);
    }

    /// @dev burns tokens from a recipient
    function _redeem(address from, uint256 amount, bytes calldata data) internal virtual {
        if (data.length != 0 && !hasRole(ERC1594_REDEEMER_ROLE, _msgSender())) {
            (bool authorized, address authorizer) = _validateData(ERC1594_REDEEMER_ROLE, from, address(0), amount, data);
            if (!authorized) revert ERC1594_InvalidSignatureData();
            _spendNonce(ERC1594_REDEEMER_ROLE, authorizer);
        }
        _burn(from, amount);
        emit Redeemed(_msgSender(), from, amount, data);
    }

    /// @dev transfers tokens from a sender to a recipient with data
    function _transferWithData(address from, address to, uint256 amount, bytes calldata data) internal virtual {
        (bool authorized, address authorizer) = _validateData(ERC1594_TRANSFER_AGENT_ROLE, from, to, amount, data);
        if (!authorized) revert ERC1594_InvalidSignatureData();
        _spendNonce(ERC1594_TRANSFER_AGENT_ROLE, authorizer);
        _transfer(from, to, amount);
        emit TransferWithData(_msgSender(), to, amount, data);
    }

    /**
     * @dev returns true if recovered signer is the authorized body
     * @param from address of the owner or authorized body
     * @param to address of the receiver
     * @param amount amount of tokens
     * @param data data parameter
     */
    function _validateData(bytes32 authorizerRole, address from, address to, uint256 amount, bytes calldata data)
        internal
        view
        virtual
        returns (bool, address authorizer)
    {
        (bytes memory signature, uint48 deadline) = abi.decode(data, (bytes, uint48));

        bytes32 authorizerRole_ = authorizerRole;
        bytes32 structData = keccak256(
            abi.encodePacked(ERC1594_DATA_VALIDATION_HASH, from, to, amount, _roleNonce[authorizerRole_], deadline)
        );
        address recoveredSigner = ECDSA.recover(_hashTypedDataV4(structData), signature);

        return (hasRole(authorizerRole_, recoveredSigner), recoveredSigner);
    }

    /**
     * @dev disables issuance of tokens, can only be called by the owner
     */
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
