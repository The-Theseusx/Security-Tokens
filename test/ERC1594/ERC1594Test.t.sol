//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1594IssuanceTest } from "./ERC1594IssuanceTest.t.sol";
import { ERC1594RedemptionTest } from "./ERC1594RedemptionTest.t.sol";
import { ERC1594TransferTest } from "./ERC1594TransferTest.t.sol";

contract ERC1594Test is ERC1594IssuanceTest, ERC1594RedemptionTest, ERC1594TransferTest { }
