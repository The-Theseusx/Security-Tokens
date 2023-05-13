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
 * @dev Thoughts: Due to somewhat old standard, transfers with data should return booleans to be truly ERC20 compatible, no?
 * @dev Thoughts: Utilize signature verification for transfers with data? If so, how to handle the data? Should it be a struct? EIP712?
 */

contract ERC1594 is IERC1594, ERC20, EIP712, Ownable2Step {
	/**
	 * @dev EIP712 typehash for data validation
	 */
	bytes32 public constant ERC1594_DATA_VALIDATION_HASH =
		keccak256("ERC1594ValidData(address from,address to,uint256 amount)");

	/**
	 * @dev should track if token is issuable or not. Should not be modifiable if false.
	 * @dev default to true. See _disableIssuance() to disable.
	 */
	bool private _isIssuable = true;

	event TransferWithData(address indexed from, address indexed to, uint256 amount, bytes data);
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
		_redeem(amount, data);
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
		_transferWithData(from, to, amount, data);
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
		if (data.length == 0) return (true, bytes("0x51"), bytes32(0)); //no data just check for transferability
		if (data.length != 0) {
			///cannot validate data because this is a view function
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
		bytes memory data
	) public view virtual override returns (bool, bytes memory, bytes32) {
		if (amount > allowance(from, msg.sender)) return (false, bytes("0x53"), bytes32(0));
		if (balanceOf(from) < amount) return (false, bytes("0x52"), bytes32(0));
		if (to == address(0)) return (false, bytes("0x57"), bytes32(0));
		if (data.length == 0) return (true, bytes("0x51"), bytes32(0)); //no data just check for transferability
		if (data.length != 0) {
			///cannot validate data because this is a view function
		}
		return (true, bytes("0x51"), bytes32(0));
	}

	function _disableIssuance() internal virtual {
		_isIssuable = false;
		emit IssuanceDisabled();
	}

	function _issue(address tokenHolder, uint256 amount, bytes calldata data) internal virtual {
		_beforeTokenTransferWithData(address(0), tokenHolder, amount, data);
		if (data.length != 0) {
			require(_validateData(owner(), tokenHolder, amount, data), "ERC1594: invalid data");
		}
		_mint(tokenHolder, amount);
		emit Issued(msg.sender, tokenHolder, amount, data);
		_afterTokenTransferWithData(address(0), tokenHolder, amount, data);
	}

	function _transferWithData(address from, address to, uint256 amount, bytes calldata data) internal virtual {
		_beforeTokenTransferWithData(from, to, amount, data);
		if (data.length != 0) {
			require(_validateData(owner(), to, amount, data), "ERC1594: invalid data");
		}

		_transfer(from, to, amount);
		emit TransferWithData(msg.sender, to, amount, data);
		_afterTokenTransferWithData(from, to, amount, data);
	}

	function _redeem(uint256 amount, bytes calldata data) internal virtual {
		_beforeTokenTransferWithData(msg.sender, address(0), amount, data);

		if (data.length != 0) {
			require(_validateData(msg.sender, owner(), amount, data), "ERC1594: invalid data");
		}

		_burn(msg.sender, amount);
		emit Redeemed(msg.sender, msg.sender, amount, data);
		_afterTokenTransferWithData(msg.sender, address(0), amount, data);
	}

	function _redeemFrom(address tokenHolder, uint256 amount, bytes calldata data) internal virtual {
		_beforeTokenTransferWithData(tokenHolder, address(0), amount, data);

		if (data.length != 0) {
			require(_validateData(owner(), tokenHolder, amount, data), "ERC1594: invalid data");
		}
		_burn(tokenHolder, amount);
		emit Redeemed(msg.sender, tokenHolder, amount, data);
		_afterTokenTransferWithData(tokenHolder, address(0), amount, data);
	}

	///@param from address of the owner or authorized body
	///@param to address of the receiver
	///@param amount amount of tokens
	///@param signature data parameter
	function _validateData(
		address from,
		address to,
		uint256 amount,
		bytes calldata signature
	) internal virtual returns (bool) {
		bytes32 structData = keccak256(abi.encodePacked(ERC1594_DATA_VALIDATION_HASH, from, to, amount));
		bytes32 structDataHash = _hashTypedDataV4(structData);
		address recoveredSigner = ECDSA.recover(structDataHash, signature);

		return recoveredSigner == from;
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
