// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/SolvencyGuard.sol";

/// @title SolvencyGuard Tests — SE-1 Invariant Verification
/// @author Abdulwahed Mansour — Sunna Protocol
contract SolvencyGuardTest is Test {
    SolvencyGuard guard;
    address engine = makeAddr("engine");
    address admin;

    function setUp() public {
        admin = address(this);
        guard = new SolvencyGuard();
        guard.authorizeEngine(engine);
    }

    // ──────────────────────────────────────
    // SE-1: Solvency Invariant
    // ──────────────────────────────────────

    function test_initialState_solvent() public view {
        assertTrue(guard.isSolvent());
        assertEq(guard.currentDeficit(), 0);
    }

    function test_increaseAssets_updatesTotalAssets() public {
        vm.prank(engine);
        guard.increaseAssets(1000);
        assertEq(guard.totalAssets(), 1000);
    }

    function test_reportLoss_reducesAssets() public {
        vm.prank(engine);
        guard.increaseAssets(1000);

        vm.prank(engine);
        guard.reportLoss(400);

        assertEq(guard.totalAssets(), 600);
    }

    function test_reportLoss_revertsWhenExceedsAssets() public {
        vm.prank(engine);
        guard.increaseAssets(1000);

        vm.prank(engine);
        vm.expectRevert(abi.encodeWithSelector(
            SolvencyGuard.LossExceedsAssets.selector, 1500, 1000
        ));
        guard.reportLoss(1500);
    }

    function test_decreaseAssets_revertsWhenBreaksSolvency() public {
        vm.prank(engine);
        guard.increaseAssets(1000);

        vm.prank(engine);
        guard.setLiabilities(800);

        // Trying to decrease to 500 (below liabilities of 800)
        vm.prank(engine);
        vm.expectRevert(abi.encodeWithSelector(
            SolvencyGuard.SolvencyViolation.selector, 500, 800
        ));
        guard.decreaseAssets(500);
    }

    function test_enforceSolvency_revertsWhenInsolvent() public {
        vm.prank(engine);
        guard.increaseAssets(100);

        vm.prank(engine);
        guard.setLiabilities(200);

        vm.expectRevert(abi.encodeWithSelector(
            SolvencyGuard.SolvencyViolation.selector, 100, 200
        ));
        guard.enforceSolvency();
    }

    function test_currentDeficit_calculatesCorrectly() public {
        vm.prank(engine);
        guard.increaseAssets(100);

        vm.prank(engine);
        guard.setLiabilities(250);

        assertEq(guard.currentDeficit(), 150);
    }

    // ──────────────────────────────────────
    // Access Control
    // ──────────────────────────────────────

    function test_onlyEngine_canUpdateState() public {
        address rando = makeAddr("rando");

        vm.prank(rando);
        vm.expectRevert(SolvencyGuard.OnlyEngine.selector);
        guard.increaseAssets(100);
    }

    function test_authorizeEngine_onlyAdmin() public {
        address newEngine = makeAddr("newEngine");
        guard.authorizeEngine(newEngine);
        assertTrue(guard.authorizedEngines(newEngine));
    }

    function test_revokeEngine_blocksAccess() public {
        guard.revokeEngine(engine);

        vm.prank(engine);
        vm.expectRevert(SolvencyGuard.OnlyEngine.selector);
        guard.increaseAssets(100);
    }

    // ──────────────────────────────────────
    // Fuzz Tests
    // ──────────────────────────────────────

    function testFuzz_reportLoss_neverExceedsAssets(uint256 assets, uint256 loss) public {
        assets = bound(assets, 1, type(uint128).max);
        loss = bound(loss, 0, assets);

        vm.prank(engine);
        guard.increaseAssets(assets);

        vm.prank(engine);
        guard.reportLoss(loss);

        assertEq(guard.totalAssets(), assets - loss);
        assertTrue(guard.totalAssets() >= 0);
    }

    function testFuzz_solvency_holdsAfterValidOperations(
        uint256 assets,
        uint256 liabilities
    ) public {
        assets = bound(assets, 0, type(uint128).max);
        liabilities = bound(liabilities, 0, assets);

        vm.prank(engine);
        guard.increaseAssets(assets);

        vm.prank(engine);
        guard.setLiabilities(liabilities);

        assertTrue(guard.isSolvent());
        assertEq(guard.currentDeficit(), 0);
    }
}
