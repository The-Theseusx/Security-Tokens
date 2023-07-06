//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import { IERC1410 } from "../ERC1410/IERC1410.sol";
import { IERC1594 } from "../ERC1594/IERC1594.sol";
import { IERC1643 } from "../ERC1643/IERC1643.sol";
import { IERC1644 } from "../ERC1644/IERC1644.sol";

interface IERC1400 is IERC1410, IERC1594, IERC1643, IERC1644 {}
