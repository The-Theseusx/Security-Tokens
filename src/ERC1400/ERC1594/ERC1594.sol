//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Ownable2Step } from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { IERC1594 } from "./IERC1594.sol";

/**
 * @title ERC1594
 * @dev ERC1594 core security logic for fungible security tokens
 */

contract ERC1594 is IERC1594, ERC20, Ownable2Step {
	/**
	 * @dev Should track if token is issuable or not. Should not be modifiable if false.
	 */
	bool private _isIssuable;

	event TransferWithData(address indexed from, address indexed to, uint256 amount, bytes data);
	event TransferFromWithData(
		address indexed operator,
		address indexed from,
		address indexed to,
		uint256 amount,
		bytes data
	);

	constructor(string memory name_, string memory symbol_, bool issue_) ERC20(name_, symbol_) {
		_isIssuable = issue_;
	}

	/**
	 * @dev See {IERC1594-isIssuable}.
	 */
	function isIssuable() public view virtual override returns (bool) {
		return _isIssuable;
	}

	/**
	 * @dev See {IERC1594-issue}.
	 */
	function issue(address tokenHolder, uint256 amount, bytes memory data) public virtual override onlyOwner {
		require(_isIssuable, "ERC1594: not issuable");
		_issue(tokenHolder, amount, data);
	}

	/**
	 * @dev See {IERC1594-redeem}.
	 */
	function redeem(uint256 amount, bytes memory data) public virtual override {
		_burn(msg.sender, amount);
		emit Redeemed(msg.sender, msg.sender, amount, data);
	}

	/**
	 * @dev See {IERC1594-redeemFrom}.
	 */
	function redeemFrom(address tokenHolder, uint256 amount, bytes memory data) public virtual override onlyOwner {
		_burn(tokenHolder, amount);
		emit Redeemed(msg.sender, tokenHolder, amount, data);
	}

	/**
	 * @dev See {IERC1594-transferWithData}.
	 */
	function transferWithData(address to, uint256 amount, bytes memory data) public virtual override {
		transfer(to, amount);
		emit TransferWithData(msg.sender, to, amount, data);
	}

	/**
	 * @dev See {IERC1594-transferFromWithData}.
	 */
	function transferFromWithData(address from, address to, uint256 amount, bytes memory data) public virtual override {
		transferFrom(from, to, amount);
		emit TransferFromWithData(msg.sender, from, to, amount, data);
	}

	/**
	 * @dev See {IERC1594-canTransfer}.
	 */
	function canTransfer(
		address to,
		uint256 amount,
		bytes memory data
	) public view virtual override returns (bool, bytes memory, bytes32) {
		if (balanceOf(msg.sender) < amount) return (false, bytes("0x52"), bytes32(0));
		if (to == address(0)) return (false, bytes("0x57"), bytes32(0));
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
		return (true, bytes("0x51"), bytes32(0));
	}

	function _issue(address tokenHolder, uint256 amount, bytes memory data) internal virtual {
		_beforeTokenTransferWithData(address(0), tokenHolder, amount, data);
		_mint(tokenHolder, amount);
		emit Issued(msg.sender, tokenHolder, amount, data);
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
	function _afterTokenTransferWithData(address from, address to, uint256 amount) internal virtual {}
}
