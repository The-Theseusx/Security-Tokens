//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1594NFT } from "../../ERC1594/ERC1594NFT/ERC1594NFT.sol";
import { IERC1644NFT } from "./IERC1644NFT.sol";

contract ERC1644NFT is ERC1594NFT, IERC1644NFT {
	/// @dev address of the controller
	address[] private _controllers;

	///@dev mapping of controller to index in _controllers array.
	mapping(address => uint256) private _controllerIndex;

	event ControllerAdded(address indexed controller);
	event ControllerRemoved(address indexed controller);

	error ERC1644NFT_NotAController();
	error ERC1644NFT_InvalidController(address controller);

	modifier onlyController() {
		if (_controllers.length == 0 || _controllers[_controllerIndex[_msgSender()]] != _msgSender()) {
			revert ERC1644NFT_NotAController();
		}
		_;
	}
	event ControllerUpdated(address indexed previousController, address indexed controller);

	constructor(
		string memory name_,
		string memory symbol_,
		string memory version_,
		address tokenAdmin,
		address tokenIssuer,
		address tokenRedeemer,
		address tokenTransferAgent
	) ERC1594NFT(name_, symbol_, version_, tokenAdmin, tokenIssuer, tokenRedeemer, tokenTransferAgent) {}

	function isControllable() public view virtual override returns (bool) {
		return _controllers.length != 0;
	}

	/// @return true if @param controller is a controller of this token.
	function isController(address controller) public view virtual returns (bool) {
		return _controllers.length != 0 && controller == _controllers[_controllerIndex[controller]];
	}

	/// @return the list of controllers of this token.
	function getControllers() public view virtual returns (address[] memory) {
		return _controllers;
	}

	///  @notice add controllers for the token.
	function addControllers(address[] memory controllers) public virtual onlyRole(ERC1594NFT_ADMIN_ROLE) {
		uint256 controllersLength = controllers.length;
		uint256 i;

		for (; i < controllersLength; ++i) {
			if (controllers[i] == address(0)) revert ERC1644NFT_InvalidController(controllers[i]);
			if (isController(controllers[i])) continue;

			uint256 newControllerIndex = _controllers.length;

			_controllers.push(controllers[i]);
			_controllerIndex[controllers[i]] = newControllerIndex;
			emit ControllerAdded(controllers[i]);
		}
	}

	/// @notice remove controllers for the token.
	function removeControllers(address[] memory controllers) external virtual onlyRole(ERC1594NFT_ADMIN_ROLE) {
		uint256 controllersLength = controllers.length;
		uint256 i;

		for (; i < controllersLength; ++i) {
			if (controllers[i] == address(0)) revert ERC1644NFT_InvalidController(controllers[i]);

			uint256 controllerIndex = _controllerIndex[controllers[i]];

			if (!isController(controllers[i])) continue;

			uint256 lastControllerIndex = _controllers.length - 1;
			address lastController = _controllers[lastControllerIndex];

			_controllers[controllerIndex] = lastController;
			_controllerIndex[lastController] = controllerIndex;
			delete _controllerIndex[controllers[i]];
			_controllers.pop();

			emit ControllerRemoved(controllers[i]);
		}
	}

	function controllerTransfer(
		address from,
		address to,
		uint256 tokenId,
		bytes calldata data,
		bytes calldata operatorData
	) public virtual override onlyController {
		_transfer(from, to, tokenId);

		emit ControllerTransfer(_msgSender(), from, to, tokenId, data, operatorData);
	}

	/**
	 * @dev See {IERC1644-controllerRedeem}.
	 */
	function controllerRedeem(
		address tokenHolder,
		uint256 tokenId,
		bytes calldata data,
		bytes calldata operatorData
	) public virtual override onlyController {
		_burn(tokenId);

		emit ControllerRedemption(_msgSender(), tokenHolder, tokenId, data, operatorData);
	}
}
