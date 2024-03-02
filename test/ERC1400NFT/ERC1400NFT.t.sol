//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC1400NFTBaseTest} from "./ERC1400NFTBaseTest.t.sol";
import {ERC1400NFTApprovalTest} from "./ERC1400NFTApproval.t.sol";
import {ERC1400NFTIssuanceTest} from "./ERC1400NFTIssuance.t.sol";
import {ERC1400NFTRedemptionTest} from "./ERC1400NFTRedemption.t.sol";
import {ERC1400NFTDocumentTest} from "./ERC1400NFTDocument.t.sol";
import {ERC1400NFTTransferTest} from "./ERC1400NFTTransfer.t.sol";

contract ERC1400NFTTest is
    ERC1400NFTBaseTest,
    ERC1400NFTApprovalTest,
    ERC1400NFTIssuanceTest,
    ERC1400NFTRedemptionTest,
    ERC1400NFTDocumentTest,
    ERC1400NFTTransferTest
{
    function testItHasAName() public {
        string memory name = ERC1400NFTMockToken.name();
        assertEq(name, TOKEN_NAME, "token name is not correct");
    }

    function testItHasASymbol() public {
        string memory symbol = ERC1400NFTMockToken.symbol();
        assertEq(symbol, TOKEN_SYMBOL, "token symbol is not correct");
    }

    function testShouldNotDisableIssuanceWhenNotAdmin() public {
        vm.startPrank(notTokenAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, notTokenAdmin, ERC1400NFTMockToken.ERC1400_NFT_ADMIN_ROLE()
            )
        );
        ERC1400NFTMockToken.disableIssuance();
        vm.stopPrank();
    }

    function testShouldDisableIssuanceWhenAdmin() public {
        vm.startPrank(tokenAdmin);
        ERC1400NFTMockToken.disableIssuance();
        vm.stopPrank();

        assertFalse(ERC1400NFTMockToken.isIssuable(), "Token should not be issuable");
    }

    function testShouldNotApproveSenderAsOperator() public {
        vm.startPrank(alice);
        vm.expectRevert("ERC1400NFT: self authorization not allowed");
        ERC1400NFTMockToken.authorizeOperator(alice);
        vm.stopPrank();
    }

    function testShouldApproveOperator() public {
        vm.startPrank(alice);

        vm.expectEmit(true, true, true, false);
        emit AuthorizedOperator(aliceOperator, alice);

        ERC1400NFTMockToken.authorizeOperator(aliceOperator);
        vm.stopPrank();

        assertTrue(ERC1400NFTMockToken.isOperator(aliceOperator, alice), "aliceOperator should be an operator");
    }

    function testShouldNotApproveSenderAsOperatorByPartition() public {
        vm.startPrank(alice);
        vm.expectRevert("ERC1400NFT: self authorization not allowed");
        ERC1400NFTMockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, alice);
        vm.stopPrank();
    }

    function testShouldApproveOperatorByPartition() public {
        vm.startPrank(alice);

        vm.expectEmit(true, true, true, true);
        emit AuthorizedOperatorByPartition(SHARED_SPACES_PARTITION, aliceOperator, alice);

        ERC1400NFTMockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, aliceOperator);
        vm.stopPrank();

        assertFalse(
            ERC1400NFTMockToken.isOperator(aliceOperator, alice),
            "aliceOperator should not be an operator but operator of shared spaces Partition"
        );
        assertFalse(
            ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, aliceOperator, alice),
            "aliceOperator should be an operator for the default partition"
        );
        assertTrue(
            ERC1400NFTMockToken.isOperatorForPartition(SHARED_SPACES_PARTITION, aliceOperator, alice),
            "aliceOperator should be an operator for shared spaces partition"
        );
    }

    function testShouldApproveOperatorForDefaultPartition() public {
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit AuthorizedOperatorByPartition(DEFAULT_PARTITION, bobOperator, bob);

        ERC1400NFTMockToken.authorizeOperatorByPartition(DEFAULT_PARTITION, bobOperator);
        vm.stopPrank();

        assertFalse(
            ERC1400NFTMockToken.isOperator(bobOperator, bob),
            "aliceOperator should not be an operator but operator of shared spaces Partition"
        );
        assertFalse(
            ERC1400NFTMockToken.isOperatorForPartition(SHARED_SPACES_PARTITION, bobOperator, bob),
            "aliceOperator should be an operator for the default partition"
        );
        assertTrue(
            ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, bobOperator, bob),
            "aliceOperator should be an operator for shared spaces partition"
        );
    }

    function testShouldRevokeOperator() public {
        vm.startPrank(alice);
        ERC1400NFTMockToken.authorizeOperator(aliceOperator);

        skip(1 minutes);

        vm.expectEmit(true, true, true, false);
        emit RevokedOperator(aliceOperator, alice);

        ERC1400NFTMockToken.revokeOperator(aliceOperator);

        assertFalse(ERC1400NFTMockToken.isOperator(aliceOperator, alice), "aliceOperator should be revoked");
        vm.stopPrank();
    }

    function testShouldRevokeAllOperatorsOfUser() public {
        vm.startPrank(bob);
        ERC1400NFTMockToken.authorizeOperator(aliceOperator);
        ERC1400NFTMockToken.authorizeOperator(bobOperator);
        ERC1400NFTMockToken.authorizeOperatorByPartition(DEFAULT_PARTITION, tokenAdminOperator);
        ERC1400NFTMockToken.authorizeOperatorByPartition(SHARED_SPACES_PARTITION, notTokenAdminOperator);
        vm.stopPrank();

        assertTrue(ERC1400NFTMockToken.isOperator(aliceOperator, bob), "aliceOperator should be an operator for Bob");
        assertTrue(ERC1400NFTMockToken.isOperator(bobOperator, bob), "bobOperator should be an operator for Bob");
        assertTrue(
            ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, tokenAdminOperator, bob),
            "tokenAdminOperator should be an operator of the default partition for Bob"
        );
        assertTrue(
            ERC1400NFTMockToken.isOperatorForPartition(SHARED_SPACES_PARTITION, notTokenAdminOperator, bob),
            "notTokenAdminOperator should be an operator of shared spaces partition for Bob"
        );

        address[] memory operators = new address[](4);
        operators[0] = bobOperator;
        operators[1] = aliceOperator;
        operators[2] = tokenAdminOperator;
        operators[3] = notTokenAdminOperator;

        vm.startPrank(bob);
        ERC1400NFTMockToken.revokeOperators(operators);
        vm.stopPrank();

        assertFalse(
            ERC1400NFTMockToken.isOperator(aliceOperator, bob), "aliceOperator should not be an operator for Bob"
        );
        assertFalse(ERC1400NFTMockToken.isOperator(bobOperator, bob), "bobOperator should not be an operator for Bob");
        assertFalse(
            ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, tokenAdminOperator, bob),
            "tokenAdminOperator should not be an operator of the default partition for Bob"
        );
        assertFalse(
            ERC1400NFTMockToken.isOperatorForPartition(SHARED_SPACES_PARTITION, notTokenAdminOperator, bob),
            "notTokenAdminOperator should not be an operator of shared spaces partition for Bob"
        );
    }

    function testShouldRevokeOperatorsForDefaultPartitionOnly() public {
        ///@dev @notice notTokenAdmin has no tokens and no partitions.
        vm.startPrank(notTokenAdmin);
        ERC1400NFTMockToken.authorizeOperatorByPartition(DEFAULT_PARTITION, tokenAdminOperator);
        ERC1400NFTMockToken.authorizeOperatorByPartition(DEFAULT_PARTITION, notTokenAdminOperator);
        vm.stopPrank();

        assertTrue(
            ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, tokenAdminOperator, notTokenAdmin),
            "tokenAdminOperator should be an operator of the default partition for notTokenAdmin"
        );

        assertTrue(
            ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, notTokenAdminOperator, notTokenAdmin),
            "notTokenAdminOperator should be an operator of the default partition for notTokenAdmin"
        );

        address[] memory operators = new address[](2);
        operators[0] = tokenAdminOperator;
        operators[1] = notTokenAdminOperator;

        vm.startPrank(notTokenAdmin);
        ERC1400NFTMockToken.revokeOperators(operators);
        vm.stopPrank();

        assertFalse(
            ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, tokenAdminOperator, notTokenAdmin),
            "tokenAdminOperator should not be an operator of the default partition for notTokenAdmin"
        );

        assertFalse(
            ERC1400NFTMockToken.isOperatorForPartition(DEFAULT_PARTITION, notTokenAdminOperator, notTokenAdmin),
            "notTokenAdminOperator should not be an operator of the default partition for notTokenAdmin"
        );
    }

    function testShouldNotAddControllersWhenNotAdmin() public {
        address[] memory controllers = new address[](3);
        controllers[0] = tokenController1;
        controllers[1] = tokenController2;
        controllers[2] = tokenController3;

        vm.startPrank(notTokenAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, notTokenAdmin, ERC1400NFTMockToken.ERC1400_NFT_ADMIN_ROLE()
            )
        );
        ERC1400NFTMockToken.addControllers(controllers);
        vm.stopPrank();
    }

    function testShouldNotAddAddressZeroAsController() public {
        address[] memory controllers = new address[](3);
        controllers[0] = tokenController1;
        controllers[1] = address(0);
        controllers[2] = tokenController3;

        vm.startPrank(tokenAdmin);
        vm.expectRevert("ERC1400NFT: controller is zero address");
        ERC1400NFTMockToken.addControllers(controllers);
        vm.stopPrank();
    }

    function testShouldAddControllers() public {
        address[] memory controllers = new address[](3);
        controllers[0] = tokenController1;
        controllers[1] = tokenController2;
        controllers[2] = tokenController3;

        vm.startPrank(tokenAdmin);
        for (uint256 i; i < controllers.length; ++i) {
            vm.expectEmit(true, true, false, false);
            emit ControllerAdded(controllers[i]);
        }
        ERC1400NFTMockToken.addControllers(controllers);
        vm.stopPrank();

        assertTrue(ERC1400NFTMockToken.isControllable(), "Token should be controllable");
        assertTrue(ERC1400NFTMockToken.isController(controllers[0]), "controller[0] should be a controller");
        assertTrue(ERC1400NFTMockToken.isController(controllers[1]), "controller[1] should be a controller");
        assertTrue(ERC1400NFTMockToken.isController(controllers[2]), "controller[2] should be a controller");
    }

    function testShouldNotRemoveControllersWhenNotAdmin() public {
        address[] memory controllers = new address[](3);
        controllers[0] = tokenController1;
        controllers[1] = tokenController2;
        controllers[2] = tokenController3;

        vm.startPrank(notTokenAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, notTokenAdmin, ERC1400NFTMockToken.ERC1400_NFT_ADMIN_ROLE()
            )
        );
        ERC1400NFTMockToken.removeControllers(controllers);
        vm.stopPrank();
    }

    function testShouldNotRemoveControllerAddress0() public {
        vm.startPrank(tokenAdmin);
        _addControllers();
        ///@dev adding controllers

        address[] memory controllers = new address[](3);
        controllers[0] = tokenController1;
        controllers[1] = address(0);
        controllers[2] = tokenController3;

        vm.expectRevert("ERC1400NFT: controller is zero address");
        ERC1400NFTMockToken.removeControllers(controllers);
        vm.stopPrank();
    }

    function testShouldNotRemoveNonControllers() public {
        vm.startPrank(tokenAdmin);

        _addControllers();

        ///@dev adding controllers

        address[] memory controllers = new address[](3);
        controllers[0] = tokenController1;
        controllers[1] = tokenController3;
        controllers[2] = notTokenAdmin;

        vm.expectRevert("ERC1400NFT: not controller");
        ERC1400NFTMockToken.removeControllers(controllers);
        vm.stopPrank();
    }

    function testShouldRemoveControllers() public {
        vm.startPrank(tokenAdmin);

        _addControllers();

        ///@dev adding controllers
        address[] memory controllers = new address[](2);
        controllers[0] = tokenController2;
        controllers[1] = tokenController3;

        for (uint256 i; i < controllers.length; ++i) {
            vm.expectEmit(true, true, false, false);
            emit ControllerRemoved(controllers[i]);
        }
        ERC1400NFTMockToken.removeControllers(controllers);
        vm.stopPrank();

        ///@notice we did not remove tokenController1 as a controller at this point

        assertTrue(ERC1400NFTMockToken.isControllable(), "Token should be controllable");
        assertTrue(ERC1400NFTMockToken.isController(tokenController1), "tokenController1 should be a controller");
        assertFalse(ERC1400NFTMockToken.isController(controllers[0]), "tokenController2 should not be a controller");
        assertFalse(ERC1400NFTMockToken.isController(controllers[1]), "tokenController3 should not be a controller");

        ///@dev finally remove all controllers
        address[] memory controllers_ = new address[](1);
        controllers_[0] = tokenController1;
        vm.startPrank(tokenAdmin);
        ERC1400NFTMockToken.removeControllers(controllers_);
        vm.stopPrank();

        assertFalse(ERC1400NFTMockToken.isControllable(), "Token should not be controllable");
        assertFalse(ERC1400NFTMockToken.isController(tokenController1), "tokenController1 should not be a controller");
    }

    function testUserPartitionsUpdateProperly() public {
        bytes32 newPartition1 = keccak256("newPartition1");
        bytes32 newPartition2 = keccak256("newPartition2");

        vm.startPrank(tokenIssuer);
        _issueTokens(newPartition1, alice, 4, "");
        _issueTokens(newPartition2, alice, 5, "");
        _issueTokens(newPartition1, bob, 6, "");
        vm.stopPrank();

        ///@dev alice should have 3 partitions (shared spaces, newPartition1, newPartition2)

        bytes32[] memory alicePartitions = ERC1400NFTMockToken.partitionsOf(alice);
        assertEq(alicePartitions.length, 3, "alice should have 3 partitions");
        assertEq(alicePartitions[0], SHARED_SPACES_PARTITION, "alice should have shared spaces partition");
        assertEq(alicePartitions[1], newPartition1, "alice should have newPartition1");
        assertEq(alicePartitions[2], newPartition2, "alice should have newPartition2");

        assertTrue(
            ERC1400NFTMockToken.isUserPartition(SHARED_SPACES_PARTITION, alice),
            "alice should have shared spaces partition"
        );
        assertTrue(
            ERC1400NFTMockToken.isUserPartition(newPartition1, alice), "alice should have newPartition1 partition"
        );
        assertTrue(
            ERC1400NFTMockToken.isUserPartition(newPartition2, alice), "alice should have newPartition2 partition"
        );

        ///@dev bob should have 2 partitions (SHARED_SPACES_PARTITION, newPartition1)

        bytes32[] memory bobPartitions = ERC1400NFTMockToken.partitionsOf(bob);
        assertEq(bobPartitions.length, 2, "bob should have 2 partitions");
        assertEq(bobPartitions[0], SHARED_SPACES_PARTITION, "bob should have default partition");
        assertEq(bobPartitions[1], newPartition1, "bob should have newPartition1");

        assertTrue(
            ERC1400NFTMockToken.isUserPartition(SHARED_SPACES_PARTITION, bob), "bob should have shared spaces partition"
        );
        assertTrue(ERC1400NFTMockToken.isUserPartition(newPartition1, bob), "bob should have newPartition1 partition");
        assertFalse(
            ERC1400NFTMockToken.isUserPartition(newPartition2, bob), "bob should not have newPartition2 partition"
        );
    }
}
