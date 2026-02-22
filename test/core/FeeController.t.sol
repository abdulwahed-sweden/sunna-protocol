// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/FeeController.sol";
import "../../src/core/SolvencyGuard.sol";

/// @title FeeController Tests — PY-1 Phantom Yield Prevention
/// @author Abdulwahed Mansour — Sunna Protocol
contract FeeControllerTest is Test {
    SolvencyGuard guard;
    FeeController controller;
    address engine = makeAddr("engine");

    function setUp() public {
        guard = new SolvencyGuard();
        guard.authorizeEngine(engine);
        controller = new FeeController(address(guard), 500); // 5% fee
    }

    // ──────────────────────────────────────
    // PY-1: No Fee During Deficit
    // ──────────────────────────────────────

    function test_calculateFee_zeroWhenDeficit() public {
        // Create deficit: liabilities > assets
        vm.startPrank(engine);
        guard.increaseAssets(100);
        guard.setLiabilities(200);
        vm.stopPrank();

        uint256 fee = controller.calculateFee(10_000);
        assertEq(fee, 0, "Fee must be zero during deficit");
    }

    function test_calculateFee_correctWhenSolvent() public {
        vm.startPrank(engine);
        guard.increaseAssets(1000);
        guard.setLiabilities(500);
        vm.stopPrank();

        uint256 fee = controller.calculateFee(10_000);
        // 10000 * 500 / 10000 = 500
        assertEq(fee, 500);
    }

    function test_calculateFee_zeroProfit() public {
        vm.startPrank(engine);
        guard.increaseAssets(1000);
        vm.stopPrank();

        uint256 fee = controller.calculateFee(0);
        assertEq(fee, 0);
    }

    function test_previewFee_blockedDuringDeficit() public {
        vm.startPrank(engine);
        guard.increaseAssets(10);
        guard.setLiabilities(100);
        vm.stopPrank();

        (uint256 fee, bool blocked) = controller.previewFee(5000);
        assertEq(fee, 0);
        assertTrue(blocked);
    }

    function test_previewFee_notBlockedWhenSolvent() public {
        vm.startPrank(engine);
        guard.increaseAssets(1000);
        vm.stopPrank();

        (uint256 fee, bool blocked) = controller.previewFee(5000);
        assertEq(fee, 250); // 5000 * 500 / 10000
        assertFalse(blocked);
    }

    // ──────────────────────────────────────
    // Fee Tracking
    // ──────────────────────────────────────

    function test_totalFeesBlocked_accumulates() public {
        vm.startPrank(engine);
        guard.increaseAssets(10);
        guard.setLiabilities(100);
        vm.stopPrank();

        controller.calculateFee(10_000);
        controller.calculateFee(20_000);

        // Should have accumulated 500 + 1000 = 1500 blocked
        assertEq(controller.totalFeesBlocked(), 1500);
    }

    function test_totalFeesCalculated_accumulates() public {
        vm.startPrank(engine);
        guard.increaseAssets(1000);
        vm.stopPrank();

        controller.calculateFee(10_000);
        controller.calculateFee(20_000);

        // 500 + 1000 = 1500
        assertEq(controller.totalFeesCalculated(), 1500);
    }

    // ──────────────────────────────────────
    // Admin
    // ──────────────────────────────────────

    function test_setFeeBps_revertsAboveMax() public {
        vm.expectRevert(abi.encodeWithSelector(
            FeeController.FeeBpsTooHigh.selector, 3000, 2000
        ));
        controller.setFeeBps(3000);
    }

    // ──────────────────────────────────────
    // Fuzz: PY-1 Always Holds
    // ──────────────────────────────────────

    function testFuzz_noFeeWhenDeficitExists(
        uint128 assets,
        uint128 liabilities,
        uint128 profit
    ) public {
        assets = uint128(bound(assets, 0, type(uint64).max));
        liabilities = uint128(bound(liabilities, assets + 1, type(uint128).max));
        profit = uint128(bound(profit, 1, type(uint64).max));

        vm.startPrank(engine);
        guard.increaseAssets(assets);
        guard.setLiabilities(liabilities);
        vm.stopPrank();

        uint256 fee = controller.calculateFee(profit);
        assertEq(fee, 0, "PY-1 violated: fee extracted during deficit");
    }
}
