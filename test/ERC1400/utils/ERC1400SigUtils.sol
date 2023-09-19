//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1400TestStorage } from "./ERC1400TestStorage.sol";
import { ERC1400ValidateDataParams } from "../../../src/utils/DataTypes.sol";

abstract contract ERC1400SigUtils is ERC1400TestStorage {
	struct PrepareSignatureParams {
		uint256 signerPk;
		bytes32 authorizerRole;
		bytes32 partition;
		address from;
		address to;
		uint256 amount;
		uint256 nonce;
		uint48 deadline;
	}

	function prepareTransferSignature(
		uint256 signerPk,
		bytes32 partition,
		address from,
		address to,
		uint256 amount,
		uint256 nonce,
		uint48 deadline
	) public returns (bytes memory) {
		bytes32 role = ERC1400MockToken.ERC1400_TRANSFER_AGENT_ROLE();
		nonce = nonce == 0 ? ERC1400MockToken.getRoleNonce(role) : nonce;
		deadline = deadline == 0 ? uint48(block.timestamp + 1 minutes) : deadline;

		PrepareSignatureParams memory sigParams = PrepareSignatureParams({
			signerPk: signerPk,
			authorizerRole: role,
			partition: partition,
			from: from,
			to: to,
			amount: amount,
			nonce: nonce,
			deadline: deadline
		});

		return _prepareSignature(sigParams);
	}

	function prepareRedemptionSignature(
		uint256 signerPk,
		bytes32 partition,
		address from,
		uint256 amount,
		uint256 nonce,
		uint48 deadline
	) public returns (bytes memory) {
		bytes32 role = ERC1400MockToken.ERC1400_REDEEMER_ROLE();
		nonce = nonce == 0 ? ERC1400MockToken.getRoleNonce(role) : nonce;
		deadline = deadline == 0 ? uint48(block.timestamp + 1 minutes) : deadline;

		PrepareSignatureParams memory sigParams = PrepareSignatureParams({
			signerPk: signerPk,
			authorizerRole: role,
			partition: partition,
			from: from,
			to: address(0),
			amount: amount,
			nonce: nonce,
			deadline: deadline
		});

		return _prepareSignature(sigParams);
	}

	function _prepareSignature(PrepareSignatureParams memory _sigParams) internal returns (bytes memory) {
		ERC1400ValidateDataParams memory validationData = ERC1400ValidateDataParams({
			authorizerRole: _sigParams.authorizerRole,
			from: _sigParams.from,
			to: _sigParams.to,
			amount: _sigParams.amount,
			partition: _sigParams.partition,
			data: ""
		});

		///@dev data field in ERC1400ValidateDataParams not needed in this step hence "" is used
		bytes32 structMessage = sigUtilsContract.getERC1400TypedDataHash(
			validationData,
			_sigParams.nonce,
			_sigParams.deadline
		);

		address signer = vm.addr(_sigParams.signerPk);

		vm.startPrank(signer);
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(_sigParams.signerPk, structMessage);
		bytes memory signature = abi.encodePacked(r, s, v);
		vm.stopPrank();

		return abi.encode(signature, _sigParams.deadline);
	}
}
