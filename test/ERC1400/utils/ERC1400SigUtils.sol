//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1400TestStorage } from "./ERC1400TestStorage.sol";
import { ERC1400ValidateDataParams } from "../../../src/utils/DataTypes.sol";

abstract contract ERC1400SigUtils is ERC1400TestStorage {
	function prepareTransferSignature(
		uint256 signerPk,
		bytes32 partition,
		address from,
		address to,
		uint256 amount,
		uint256 nonce,
		uint48 deadline
	) public {}

	function prepareRedemptionSignature(
		uint256 signerPk,
		bytes32 partition,
		address from,
		uint256 amount,
		uint256 nonce,
		uint48 deadline
	) public returns (bytes memory) {
		bytes32 role_ = ERC1400MockToken.ERC1400_REDEEMER_ROLE();
		nonce = nonce == 0 ? ERC1400MockToken.getRoleNonce(role_) : nonce;
		deadline = deadline == 0 ? uint48(block.timestamp + 1 minutes) : deadline;

		ERC1400ValidateDataParams memory validationData = ERC1400ValidateDataParams({
			authorizerRole: role_,
			from: from,
			to: address(0),
			amount: amount,
			partition: partition,
			data: ""
		});

		///@dev data field in ERC1400ValidateDataParams not needed in this step hence "" is used
		bytes32 structMessage = sigUtilsContract.getERC1400TypedDataHash(validationData, nonce, deadline);

		address signer = vm.addr(signerPk);

		vm.startPrank(signer);
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, structMessage);
		bytes memory signature = abi.encodePacked(r, s, v);
		vm.stopPrank();

		bytes memory data = abi.encode(signature, deadline);
		return data;
	}
}
