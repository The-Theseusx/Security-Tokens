//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1594 } from "../../src/ERC1594/ERC1594.sol";
import { BaseTestStorage } from "./BaseTestStorage.t.sol";

abstract contract ERC1594TestStorage is BaseTestStorage {
    string public constant TOKEN_NAME = "ERC1594MockToken";
    string public constant TOKEN_SYMBOL = "ERC1594_MTK";
    string public constant TOKEN_VERSION = "1";

    uint256 public constant INITIAL_SUPPLY = 100_000_000e18;
    uint256 public constant ALICE_INITIAL_BALANCE = INITIAL_SUPPLY / 2;
    uint256 public constant BOB_INITIAL_BALANCE = INITIAL_SUPPLY / 2;

    ERC1594 public mockERC1594;

    event Issued(address indexed operator, address indexed to, uint256 amount, bytes data);
    event Redeemed(address indexed operator, address indexed from, uint256 amount, bytes data);
    event TransferWithData(address indexed from, address indexed to, uint256 amount, bytes data);

    error ERC1594_IssuanceDisabled();
    error ERC1594_InvalidAddress(address addr);
    error ERC1594_InvalidReceiver(address receiver);
    error ERC1594_ZeroAmount();
    error ERC1594_InvalidData();
    error ERC1594_InvalidSignatureData();
    error ERC1594_ExpiredSignature();

    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
}
