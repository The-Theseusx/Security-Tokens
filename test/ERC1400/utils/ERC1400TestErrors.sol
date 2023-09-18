//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";

abstract contract ERC1400TestErrors {
	function accessControlError(address account, bytes32 role) public pure returns (string memory) {
		return
			string(
				abi.encodePacked(
					"AccessControl: account ",
					Strings.toHexString(uint160(account)),
					" is missing role ",
					Strings.toHexString(uint256(role))
				)
			);
	}
}
