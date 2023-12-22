//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1400 } from "../ERC1400.sol";
import { Pausable } from "../../utils/Pausable.sol";

contract ERC1400Pausable is ERC1400, Pausable {
	constructor(
		string memory name_,
		string memory symbol_,
		string memory version_,
		address tokenAdmin_,
		address tokenIssuer_,
		address tokenRedeemer_,
		address tokenTransferAgent_
	) ERC1400(name_, symbol_, version_, tokenAdmin_, tokenIssuer_, tokenRedeemer_, tokenTransferAgent_) {}

	/**@notice Error messages:
	  -IP: Invalid partition
	  -IS: Invalid sender
	  -IPB: Insufficient partition balance
	  -IR: Receiver is invalid / cannot receive tokens
	  -ID: Invalid transfer data
	  -IA: Insufficient allowance
	  -ITA: Insufficient transfer amount
      -TP: Token is paused
      -AP: Account is paused
      -PP: Partition is paused
      */
	function canTransferByPartition(
		address from,
		address to,
		bytes32 partition,
		uint256 amount,
		bytes memory data
	) public view virtual override returns (bytes memory, bytes32, bytes32) {
		(bytes memory errCode, bytes32 errMsg, bytes32 extraData) = super.canTransferByPartition(
			from,
			to,
			partition,
			amount,
			data
		);

		if (keccak256(errCode) == keccak256("0x51")) {
			(bool _allowed, bytes memory _errCode, bytes32 _reason) = _checkPaused(partition, from, to);
			if (!_allowed) {
				errCode = _errCode;
				errMsg = _reason;
			}
		}
		return (errCode, errMsg, extraData);
	}

	function canTransfer(
		address to,
		uint256 amount,
		bytes memory data
	) public view virtual override returns (bool, bytes memory, bytes32) {
		(bool allowed, bytes memory errCode, bytes32 errReason) = super.canTransfer(to, amount, data);

		if (allowed) {
			(allowed, errCode, errReason) = _checkPaused(DEFAULT_PARTITION, _msgSender(), to);
		}
		return (allowed, errCode, errReason);
	}

	function canTransferFrom(
		address from,
		address to,
		uint256 amount,
		bytes memory data
	) public view virtual override returns (bool, bytes memory, bytes32) {
		(bool allowed, bytes memory errCode, bytes32 errReason) = super.canTransferFrom(from, to, amount, data);

		if (allowed) {
			(allowed, errCode, errReason) = _checkPaused(DEFAULT_PARTITION, from, to);
		}
		return (allowed, errCode, errReason);
	}

	function _checkPaused(
		bytes32 partition,
		address from,
		address to
	) internal view virtual returns (bool allowed, bytes memory errCode, bytes32 errReason) {
		if (paused()) {
			allowed = false;
			errCode = "0x54";
			errReason = "ERC1400: TP";
		}

		if (accountPaused(from)) {
			allowed = false;
			errCode = "0x54";
			errReason = "ERC1400: AP";
		}

		if (accountPaused(to)) {
			allowed = false;
			errCode = "0x57";
			errReason = "ERC1400: IR";
		}

		if (partitionPaused(partition)) {
			allowed = false;
			errCode = "0x54";
			errReason = "ERC1400: PP";
		}
	}
}
