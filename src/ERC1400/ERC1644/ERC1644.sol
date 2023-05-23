//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1594 } from "../ERC1594/ERC1594.sol";
import { IERC1644 } from "./IERC1644.sol";

/**
 * @title ERC1644
 * @dev ERC1644 logic. Controller for executing forced transfers and redemptions.
 */

contract ERC1644 is IERC1644, ERC1594 {
	/**
	 * @dev address of the controller
	 */
	address private _controller;

	modifier onlyController() {
		require(msg.sender == _controller, "ERC1644: not controller");
		_;
	}

	event ControllerUpdated(address indexed previousController, address indexed controller);

	constructor(
		string memory name_,
		string memory symbol_,
		string memory version_,
		address controller_
	) ERC1594(name_, symbol_, version_) {
		emit ControllerUpdated(address(0), controller_);
		_controller = controller_;
	}

	function controller() public view virtual returns (address) {
		return _controller;
	}

	/**
	 * @dev See {IERC1644-isControllable}.
	 */
	function isControllable() public view virtual override returns (bool) {
		return !(_controller == address(0));
	}

	function setController(address controller_) public virtual onlyOwner {
		emit ControllerUpdated(_controller, controller_);
		_controller = controller_;
	}

	/**
	 * @dev See {IERC1644-controllerTransfer}.
	 */
	function controllerTransfer(
		address from,
		address to,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) public virtual override onlyController {
		_controllerTransfer(from, to, amount, data, operatorData);
	}

	/**
	 * @dev See {IERC1644-controllerRedeem}.
	 */
	function controllerRedeem(
		address tokenHolder,
		uint256 value,
		bytes calldata data,
		bytes calldata operatorData
	) public virtual override onlyController {
		_controllerRedeem(tokenHolder, value, data, operatorData);
	}

	/**
	 * @dev See {IERC1644-controllerTransfer}.
	 */
	function _controllerTransfer(
		address from,
		address to,
		uint256 amount,
		bytes calldata data,
		bytes calldata operatorData
	) internal virtual {
		if (data.length == 0) {
			_transfer(from, to, amount);
		} else {
			_transferWithData(from, to, amount, data);
		}
		emit ControllerTransfer(msg.sender, from, to, amount, data, operatorData);
	}

	/**
	 * @dev See {IERC1644-controllerRedeem}.
	 */
	function _controllerRedeem(
		address tokenHolder,
		uint256 value,
		bytes calldata data,
		bytes calldata operatorData
	) internal virtual {
		if (data.length == 0) {
			_burn(tokenHolder, value);
		} else {
			_redeemFrom(tokenHolder, value, data);
		}
		emit ControllerRedemption(msg.sender, tokenHolder, value, data, operatorData);
	}

	function _transferWithData(
		address from,
		address to,
		uint256 amount,
		bytes calldata data
	) internal virtual override {
		_beforeTokenTransferWithData(from, to, amount, data);

		require(_validateData(_controller, from, to, amount, data), "ERC1594: invalid data");

		_transfer(from, to, amount);
		emit TransferWithData(msg.sender, to, amount, data);
		_afterTokenTransferWithData(from, to, amount, data);
	}

	function _redeemFrom(address tokenHolder, uint256 amount, bytes calldata data) internal virtual override {
		_beforeTokenTransferWithData(tokenHolder, address(0), amount, data);

		require(_validateData(_controller, tokenHolder, address(0), amount, data), "ERC1594: invalid data");

		_burn(tokenHolder, amount);
		emit Redeemed(msg.sender, tokenHolder, amount, data);
		_afterTokenTransferWithData(tokenHolder, address(0), amount, data);
	}
}
