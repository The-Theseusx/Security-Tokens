//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC1643 } from "../ERC1643/IERC1643.sol";

interface IERC1400 is IERC20, IERC1643 {}
