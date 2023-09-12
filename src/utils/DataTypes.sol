//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct ERC1400ValidateDataParams {
	bytes32 authorizerRole;
	address from;
	address to;
	uint256 amount;
	bytes32 partition;
	bytes data;
}

struct ERC1400NFTValidateDataParams {
	bytes32 authorizerRole;
	address from;
	address to;
	uint256 tokenId;
	bytes32 partition;
	bytes data;
}
