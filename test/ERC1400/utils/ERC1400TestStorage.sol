//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ERC1400} from "../../../src/ERC1400/ERC1400.sol";
import {SigUtils} from "../../utils/SigUtils.sol";
import {ERC1400ReceiverImplementer} from "./ERC1400ReceiverImplementer.sol";
import {NonERC1400ReceiverImplementer} from "./NonERC1400ReceiverImplementer.sol";

abstract contract ERC1400TestStorage is Test {
    string public constant TOKEN_NAME = "ERC1400MockToken";
    string public constant TOKEN_SYMBOL = "ERC1400MTK";
    string public constant TOKEN_VERSION = "1";

    bytes public constant TRANSFER_FAILURE = "0x50";
    bytes public constant TRANSFER_SUCCESS = "0x51";
    bytes public constant INSUFFICIENT_BALANCE = "0x52";
    bytes public constant INSUFFICIENT_ALLOWANCE = "0x53";
    bytes public constant TRANSFERS_HALTED = "0x54";
    bytes public constant FUNDS_LOCKED = "0x55";
    bytes public constant INVALID_SENDER = "0x56";
    bytes public constant INVALID_RECEIVER = "0x57";
    bytes public constant INVALID_OPERATOR = "0x58";
    bytes public constant INVALID_DATA_OR_TOKEN_INFO = "0x5f";
    /**
     * code	description **
     * 0x50	transfer failure
     * 0x51	transfer success
     * 0x52	insufficient balance
     * 0x53	insufficient allowance
     * 0x54	transfers halted (contract paused)
     * 0x55	funds locked (lockup period)
     * 0x56	invalid sender
     * 0x57	invalid receiver
     * 0x58	invalid operator (transfer agent)
     * 0x59
     * 0x5a
     * 0x5b
     * 0x5a
     * 0x5b
     * 0x5c
     * 0x5d
     * 0x5e
     * 0x5f	token meta or info
     */
    uint256 public constant TOKEN_ADMIN_PK = 0x100;
    uint256 public constant NOT_ADMIN_PK = 0x419;
    uint256 public constant TOKEN_ISSUER_PK = 0x200;
    uint256 public constant TOKEN_REDEEMER_PK = 0x300;
    uint256 public constant TOKEN_TRANSFER_AGENT_PK = 0x400;
    uint256 public constant ALICE_PK = 0xA11cE;
    uint256 public constant BOB_PK = 0xB0b;

    uint256 public constant TOKEN_ADMIN_OPERATOR_PK = 0x100093A0;
    uint256 public constant NOT_TOKEN_ADMIN_OPERATOR_PK = 0x419093A0;
    uint256 public constant ALICE_OPERATOR_PK = 0xA11cE093A0;
    uint256 public constant BOB_OPERATOR_PK = 0xB0b093A0;

    uint256 public constant TOKEN_CONTROLLER_1_PK = 0x1034C04101;
    uint256 public constant TOKEN_CONTROLLER_2_PK = 0x1034C04102;
    uint256 public constant TOKEN_CONTROLLER_3_PK = 0x1034C04103;

    address public constant ZERO_ADDRESS = address(0);

    ///@notice this is token total supply irrespective of partition
    uint256 public constant INITIAL_SUPPLY = 100_000_000e18;
    uint256 public constant INITIAL_DEFAULT_PARTITION_SUPPLY = 98_000_000e18;
    uint256 public constant INITIAL_SHARED_SPACES_PARTITION_SUPPLY = 2_000_000e18;

    bytes32 public constant DEFAULT_PARTITION = bytes32(0);
    bytes32 public constant SHARED_SPACES_PARTITION = keccak256("CONDOMINIUM_SHARED_SPACES");
    bytes32 public constant DOMAIN_SEPARATOR = 0x256897f89009cd54240b5755edbdc1612b7c5fb63ae29dbe64277a5dccfa3c4b;

    address public tokenAdmin = vm.addr(TOKEN_ADMIN_PK);
    address public notTokenAdmin = vm.addr(NOT_ADMIN_PK);
    address public tokenIssuer = vm.addr(TOKEN_ISSUER_PK);
    address public tokenRedeemer = vm.addr(TOKEN_REDEEMER_PK);
    address public tokenTransferAgent = vm.addr(TOKEN_TRANSFER_AGENT_PK);
    address public alice = vm.addr(ALICE_PK);
    address public bob = vm.addr(BOB_PK);

    address public tokenAdminOperator = vm.addr(TOKEN_ADMIN_OPERATOR_PK);
    address public notTokenAdminOperator = vm.addr(NOT_TOKEN_ADMIN_OPERATOR_PK);
    address public aliceOperator = vm.addr(ALICE_OPERATOR_PK);
    address public bobOperator = vm.addr(BOB_OPERATOR_PK);

    address public tokenController1 = vm.addr(TOKEN_CONTROLLER_1_PK);
    address public tokenController2 = vm.addr(TOKEN_CONTROLLER_2_PK);
    address public tokenController3 = vm.addr(TOKEN_CONTROLLER_3_PK);

    //solhint-disable-next-line var-name-mixedcase
    ERC1400 public ERC1400MockToken;

    SigUtils public sigUtilsContract;

    //solhint-disable-next-line var-name-mixedcase
    ERC1400ReceiverImplementer public ERC1400ReceivableContract;

    NonERC1400ReceiverImplementer public nonERC1400ReceivableContract;

    // Issuance / Redemption Events
    event Issued(address indexed operator, address indexed to, uint256 amount, bytes data);
    event IssuedByPartition(bytes32 indexed partition, address indexed to, uint256 amount, bytes data);
    event Redeemed(address indexed operator, address indexed from, uint256 amount, bytes data);
    event RedeemedByPartition(
        bytes32 indexed partition,
        address indexed operator,
        address indexed from,
        uint256 amount,
        bytes data,
        bytes operatorData
    );

    event NonceSpent(bytes32 indexed role, address indexed spender, uint256 nonceSpent);

    // Operator Events
    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);
    event AuthorizedOperatorByPartition(
        bytes32 indexed partition, address indexed operator, address indexed tokenHolder
    );
    event RevokedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);
    event ControllerAdded(address indexed controller);
    event ControllerRemoved(address indexed controller);
    event ControllerRedemption(
        address indexed controller, address indexed tokenHolder, uint256 amount, bytes data, bytes operatorData
    );
    event ControllerRedemptionByPartition(
        bytes32 indexed partition,
        address indexed controller,
        address indexed tokenHolder,
        uint256 amount,
        bytes data,
        bytes operatorData
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
    event TransferWithData(
        address indexed authorizer,
        address operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data
    );
    event TransferByPartition(
        bytes32 indexed fromPartition,
        address operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );
    event ControllerTransfer(
        address indexed controller,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );
    event ControllerTransferByPartition(
        bytes32 indexed partition,
        address indexed controller,
        address indexed from,
        address to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event ApprovalByPartition(
        bytes32 indexed partition, address indexed owner, address indexed spender, uint256 amount
    );
    event DocumentRemoved(bytes32 indexed name, string uri, bytes32 documentHash);
    event DocumentUpdated(bytes32 indexed name, string uri, bytes32 documentHash);

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
}
