//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { ERC1400NFT } from "../../../src/ERC1400NFT/ERC1400NFT.sol";
import { SigUtils } from "../../utils/SigUtils.sol";
import { ERC1400NFTReceiverImplementer } from "./ERC1400NFTReceiverImplementer.sol";
import { NonERC1400NFTReceiverImplementer } from "./NonERC1400NFTReceiverImplementer.sol";

abstract contract ERC1400NFTTestStorage is Test {
    string public constant TOKEN_NAME = "ERC1400NFTMockToken";
    string public constant TOKEN_SYMBOL = "ERC1400NFT_MTK";
    string public constant TOKEN_VERSION = "1";
    string public constant TOKEN_BASE_URI = "https://theseusX.io";

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

    uint256 public constant ADMIN_INITIAL_TOKEN_ID = 1;
    uint256 public constant ALICE_INITIAL_TOKEN_ID = 2;
    uint256 public constant BOB_INITIAL_TOKEN_ID = 3;

    address public constant ZERO_ADDRESS = address(0);

    bytes32 public constant DEFAULT_PARTITION = bytes32(0);
    bytes32 public constant SHARED_SPACES_PARTITION = keccak256("CONDOMINIUM_SHARED_SPACES");

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
    ERC1400NFT public ERC1400NFTMockToken;

    SigUtils public sigUtilsContract;

    //solhint-disable-next-line var-name-mixedcase
    ERC1400NFTReceiverImplementer public ERC1400NFTReceivableContract;

    NonERC1400NFTReceiverImplementer public nonERC1400NFTReceivableContract;

    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);
    event AuthorizedOperatorByPartition(
        bytes32 indexed partition, address indexed operator, address indexed tokenHolder
    );
    event RevokedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);

    // Issuance / Redemption Events
    event Issued(address indexed operator, address indexed to, uint256 tokenId, bytes data);
    event Redeemed(address indexed operator, address indexed from, uint256 tokenId, bytes data);
    event IssuedByPartition(
        bytes32 indexed partition, address indexed operator, address indexed to, uint256 tokenId, bytes data
    );
    event RedeemedByPartition(
        bytes32 indexed partition,
        address indexed operator,
        address indexed from,
        uint256 tokenId,
        bytes data,
        bytes operatorData
    );

    // Transfer Events
    event TransferByPartition(
        bytes32 indexed fromPartition,
        address operator,
        address indexed from,
        address indexed to,
        uint256 tokenId,
        bytes data,
        bytes operatorData
    );

    // Controller Events
    event ControllerTransfer(
        address indexed controller,
        address indexed from,
        address indexed to,
        uint256 tokenId,
        bytes data,
        bytes operatorData
    );

    event ControllerRedemption(
        address indexed controller, address indexed tokenHolder, uint256 tokenId, bytes data, bytes operatorData
    );
    event ControllerAdded(address indexed controller);
    event ControllerRemoved(address indexed controller);
    event ControllerRedemptionByPartition(
        bytes32 indexed partition,
        address indexed controller,
        address indexed tokenHolder,
        uint256 tokenId,
        bytes data,
        bytes operatorData
    );
    event Transfer(
        address operator,
        address indexed from,
        address indexed to,
        uint256 tokenId,
        bytes32 indexed partition,
        bytes data,
        bytes operatorData
    );
    event TransferWithData(
        address indexed authorizer,
        address operator,
        address indexed from,
        address indexed to,
        uint256 tokenId,
        bytes data
    );
    event ControllerTransferByPartition(
        bytes32 indexed partition,
        address indexed controller,
        address indexed from,
        address to,
        uint256 tokenId,
        bytes data,
        bytes operatorData
    );
    event Approval(address indexed owner, address indexed spender, uint256 tokenId, bytes32 indexed partition);
    event DocumentRemoved(bytes32 indexed name, string uri, bytes32 documentHash);
    event DocumentUpdated(bytes32 indexed name, string uri, bytes32 documentHash);

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
}
