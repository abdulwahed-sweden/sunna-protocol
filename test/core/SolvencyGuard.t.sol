// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {SolvencyGuard} from "../../src/core/SolvencyGuard.sol";

contract SolvencyGuardTest is Test {
    SolvencyGuard public guard;

    function setUp() public {
        guard = new SolvencyGuard(address(this));
    }

    function test_checkSolvency_initiallyTrue() public view {
        // assets=0, liabilities=0 => 0 >= 0 => true
        assertTrue(guard.checkSolvency());
    }

    function test_updateAssets() public {
        guard.updateAssets(1000);
        assertEq(guard.totalAssets(), 1000);
    }

    function test_updateLiabilities() public {
        guard.updateLiabilities(500);
        assertEq(guard.totalLiabilities(), 500);
    }

    function test_checkSolvency_afterUpdate() public {
        guard.updateAssets(1000);
        guard.updateLiabilities(500);
        assertTrue(guard.checkSolvency());
    }

    function test_checkSolvency_whenInsolvent() public {
        guard.updateAssets(100);
        guard.updateLiabilities(200);
        assertFalse(guard.checkSolvency());
    }

    function test_enforceSolvency_reverts_whenInsolvent() public {
        guard.updateAssets(100);
        guard.updateLiabilities(200);
        vm.expectRevert(
            abi.encodeWithSelector(SolvencyGuard.SolvencyViolation.selector, 100, 200)
        );
        guard.enforceSolvency();
    }

    function test_reportLoss() public {
        guard.updateAssets(1000);
        guard.reportLoss(300);
        assertEq(guard.totalAssets(), 700);
    }

    function test_reportLoss_revertsOnExcess() public {
        guard.updateAssets(100);
        vm.expectRevert("SUNNA: loss exceeds assets");
        guard.reportLoss(200);
    }

    function test_onlyEngine_reverts() public {
        address randomUser = address(0xBEEF);
        vm.prank(randomUser);
        vm.expectRevert(SolvencyGuard.UnauthorizedCaller.selector);
        guard.updateAssets(999);
    }
}
