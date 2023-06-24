//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { IERC1400 } from "./IERC1400.sol";

//TODO: implement ERC1400. Inherit subcontracts and override or implement from scratch?

//TODO: implement non-fungible version of ERC1400.
contract ERC1400 is Ownable2Step{
	/**
	 * @dev tokens not belonging to any partition should use this partition
	 */
	bytes32 public constant DEFAULT_PARTITION = bytes32(0);
}
