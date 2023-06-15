//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Ownable2Step } from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { IERC1594 } from "./IERC1594.sol";
import { EIP712 } from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title ERC1594
 * @dev ERC1594 core security logic for fungible security tokens
 * @dev Utilizing ERC712 and ECDSA to validate data
 */

contract ERC1594 is IERC1594, ERC20, EIP712, Ownable2Step {
	/**
	 * @dev EIP712 typehash for data validation
	 */
	bytes32 public constant ERC1594_DATA_VALIDATION_HASH =
		keccak256("ERC1594ValidateData(address from,address to,uint256 amount)");

	/**
	 * @dev should track if token is issuable or not. Should not be modifiable if false.
	 */
	bool private _isIssuable = true;

	/**
	 * @dev event emitted when tokens are transferred with data attached
	 */
	event TransferWithData(address indexed from, address indexed to, uint256 amount, bytes data);

	/**
	 * @dev event emitted when issuance is disabled
	 */
	event IssuanceDisabled();

	constructor(
		string memory name_,
		string memory symbol_,
		string memory version_
	) ERC20(name_, symbol_) EIP712(name_, version_) {}

	/**
	 * @dev See {IERC1594-isIssuable}.
	 */
	function isIssuable() public view virtual override returns (bool) {
		return _isIssuable;
	}

	/**
	 * @dev See {IERC1594-issue}.
	 */
	function issue(address tokenHolder, uint256 amount, bytes calldata data) public virtual override onlyOwner {
		require(_isIssuable, "ERC1594: not issuable");
		_issue(tokenHolder, amount, data);
	}

	/**
	 * @dev See {IERC1594-redeem}.
	 */
	function redeem(uint256 amount, bytes calldata data) public virtual override {
		_redeem(msg.sender, amount, data);
	}

	/**
	 * @dev See {IERC1594-redeemFrom}.
	 */
	function redeemFrom(address tokenHolder, uint256 amount, bytes calldata data) public virtual override onlyOwner {
		_redeemFrom(tokenHolder, amount, data);
	}

	/**
	 * @dev See {IERC1594-transferWithData}.amount
	 */
	function transferWithData(address to, uint256 amount, bytes calldata data) public virtual override {
		_transferWithData(msg.sender, to, amount, data);
	}

	/**
	 * @dev See {IERC1594-transferFromWithData}.
	 */
	function transferFromWithData(
		address from,
		address to,
		uint256 amount,
		bytes calldata data
	) public virtual override {
		_transferFromWithData(from, to, amount, data);
	}

	/**
	 * @dev See {IERC1594-canTransfer}.
	 */
	function canTransfer(
		address to,
		uint256 amount,
		bytes calldata data
	) public view virtual override returns (bool, bytes memory, bytes32) {
		if (balanceOf(msg.sender) < amount) return (false, bytes("0x52"), bytes32(0));
		if (to == address(0)) return (false, bytes("0x57"), bytes32(0));
		if (data.length != 0) {
			if (_validateData(owner(), msg.sender, to, amount, data)) return (true, bytes("0x51"), bytes32(0));
		}
		return (true, bytes("0x51"), bytes32(0));
	}

	/**
	 * @dev See {IERC1594-canTransferFrom}.
	 */
	function canTransferFrom(
		address from,
		address to,
		uint256 amount,
		bytes calldata data
	) public view virtual override returns (bool, bytes memory, bytes32) {
		if (amount > allowance(from, msg.sender)) return (false, bytes("0x53"), bytes32(0));
		return canTransfer(to, amount, data);
	}

	/**
	 * @dev issues tokens to a recipient
	 */
	function _issue(address tokenHolder, uint256 amount, bytes calldata data) internal virtual {
		_beforeTokenTransferWithData(address(0), tokenHolder, amount, data);
		if (data.length != 0) {
			require(_validateData(owner(), address(0), tokenHolder, amount, data), "ERC1594: invalid data");
		}
		_mint(tokenHolder, amount);
		emit Issued(msg.sender, tokenHolder, amount, data);
		_afterTokenTransferWithData(address(0), tokenHolder, amount, data);
	}

	/**
	 * @dev burns tokens from a recipient
	 */
	function _redeem(address from, uint256 amount, bytes calldata data) internal virtual {
		_beforeTokenTransferWithData(from, address(0), amount, data);

		if (data.length != 0) {
			require(_validateData(owner(), from, address(0), amount, data), "ERC1594: invalid data");
		}

		_burn(from, amount);
		emit Redeemed(data.length == 0 ? msg.sender : owner(), from, amount, data);
		_afterTokenTransferWithData(msg.sender, address(0), amount, data);
	}

	/**
	 * @dev burns tokens from a recipient, to be called by an approved operator
	 */
	function _redeemFrom(address tokenHolder, uint256 amount, bytes calldata data) internal virtual {
		_redeem(tokenHolder, amount, data);
	}

	/**
	 * @dev transfers tokens from a sender to a recipient with data
	 */
	function _transferWithData(address from, address to, uint256 amount, bytes calldata data) internal virtual {
		_beforeTokenTransferWithData(from, to, amount, data);

		require(_validateData(owner(), from, to, amount, data), "ERC1594: invalid data");

		_transfer(from, to, amount);
		emit TransferWithData(msg.sender, to, amount, data);
		_afterTokenTransferWithData(from, to, amount, data);
	}

	/**
	 * @dev transfers tokens from a sender to a recipient with data, to be called by an approved operator
	 */
	function _transferFromWithData(address from, address to, uint256 amount, bytes calldata data) internal virtual {
		_spendAllowance(from, to, amount);
		_transferWithData(from, to, amount, data);
	}

	/**
	 * @dev returns true if recovered signer is the authorized body
	 * @param from address of the owner or authorized body
	 * @param to address of the receiver
	 * @param amount amount of tokens
	 * @param signature data parameter
	 */
	function _validateData(
		address authorizer,
		address from,
		address to,
		uint256 amount,
		bytes calldata signature
	) internal view virtual returns (bool) {
		bytes32 structData = keccak256(abi.encodePacked(ERC1594_DATA_VALIDATION_HASH, from, to, amount));
		bytes32 structDataHash = _hashTypedDataV4(structData);
		address recoveredSigner = ECDSA.recover(structDataHash, signature);

		return recoveredSigner == authorizer;
	}

	/**
	 * @dev disables issuance of tokens, can only be called by the owner
	 */
	function disableIssuance() public virtual onlyOwner {
		_disableIssuance();
	}

	/**
	 * @dev renounce ownership and disables issuance of tokens
	 */
	function renounceOwnership() public virtual override onlyOwner {
		_disableIssuance();
		super.renounceOwnership();
	}

	/**
	 * @dev intenal function to disable issuance of tokens
	 */
	function _disableIssuance() internal virtual {
		_isIssuable = false;
		emit IssuanceDisabled();
	}

	/**
	 * @dev Hook that is called before any transfer of tokens with data. This includes
	 * issuing and redeeming.
	 *
	 * Calling conditions:
	 *
	 * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
	 * will be transferred to `to`.
	 * - when `from` is zero, `amount` tokens will be issued for `to`.
	 * - when `to` is zero, `amount` of ``from``'s tokens will be redeemed.
	 * - `from` and `to` are never both zero.
	 *
	 * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
	 */
	function _beforeTokenTransferWithData(
		address from,
		address to,
		uint256 amount,
		bytes memory data
	) internal virtual {}

	/**
	 * @dev Hook that is called after any transfer of tokens with data. This includes
	 * issuing and redeeming.
	 *
	 * Calling conditions:
	 *
	 * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
	 * has been transferred to `to`.
	 * - when `from` is zero, `amount` tokens have been issued for `to`.
	 * - when `to` is zero, `amount` of ``from``'s tokens have been redeemed.
	 * - `from` and `to` are never both zero.
	 *
	 * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
	 */
	function _afterTokenTransferWithData(
		address from,
		address to,
		uint256 amount,
		bytes memory data
	) internal virtual {}
}
