// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/mudaraba/SunnaLedger.sol";

/// @title SunnaLedger Tests — JHD Effort Measurement Verification
/// @author Abdulwahed Mansour — Sunna Protocol
contract SunnaLedgerTest is Test {
    SunnaLedger ledger;
    address recorder = makeAddr("recorder");
    address manager = makeAddr("manager");

    function setUp() public {
        ledger = new SunnaLedger();
        ledger.setAuthorizedRecorder(recorder, true);

        // Activate a project
        vm.prank(recorder);
        ledger.activateProject(0, manager);
    }

    // ──────────────────────────────────────
    // JHD Recording
    // ──────────────────────────────────────

    function test_recordEffort_tradeExecuted() public {
        vm.prank(recorder);
        ledger.recordEffort(0, manager, SunnaLedger.ActionType.TradeExecuted, keccak256("tx1"));

        SunnaLedger.ProjectEffort memory pe = ledger.getProjectEffort(0);
        assertEq(pe.totalJHD, 5);
        assertEq(pe.entryCount, 1);
    }

    function test_recordEffort_accumulates() public {
        vm.startPrank(recorder);
        // 5 trades = 25 JHD
        for (uint256 i = 0; i < 5; i++) {
            ledger.recordEffort(0, manager, SunnaLedger.ActionType.TradeExecuted, bytes32(i));
        }
        // 2 reports = 20 JHD
        for (uint256 i = 0; i < 2; i++) {
            ledger.recordEffort(0, manager, SunnaLedger.ActionType.ReportSubmitted, bytes32(i + 100));
        }
        vm.stopPrank();

        SunnaLedger.ProjectEffort memory pe = ledger.getProjectEffort(0);
        assertEq(pe.totalJHD, 45); // 25 + 20
        assertEq(pe.entryCount, 7);
    }

    function test_recordEffort_updatesManagerStats() public {
        vm.prank(recorder);
        ledger.recordEffort(0, manager, SunnaLedger.ActionType.PortfolioRebalanced, keccak256("rebal1"));

        (uint256 lifetimeJHD,,,,,,) = ledger.getManagerStats(manager);
        assertEq(lifetimeJHD, 15);
    }

    function test_recordEffort_revertsUnauthorized() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert(SunnaLedger.UnauthorizedRecorder.selector);
        ledger.recordEffort(0, manager, SunnaLedger.ActionType.TradeExecuted, keccak256("x"));
    }

    function test_recordEffort_revertsInactiveProject() public {
        vm.prank(recorder);
        vm.expectRevert(abi.encodeWithSelector(SunnaLedger.ProjectNotActive.selector, 999));
        ledger.recordEffort(999, manager, SunnaLedger.ActionType.TradeExecuted, keccak256("x"));
    }

    // ──────────────────────────────────────
    // Efficiency Calculation
    // ──────────────────────────────────────

    function test_recordProfit_calculatesEfficiency() public {
        // Record 150 JHD (30 trades)
        vm.startPrank(recorder);
        for (uint256 i = 0; i < 30; i++) {
            ledger.recordEffort(0, manager, SunnaLedger.ActionType.TradeExecuted, bytes32(i));
        }
        vm.stopPrank();

        // Record $2200 profit
        vm.prank(recorder);
        uint256 eff = ledger.recordProfit(0, manager, 2200);

        // Efficiency = (2200 * 100) / 150 = 1466
        assertEq(eff, 1466);
    }

    function test_recordProfit_zeroJHD_returnsZero() public {
        // Activate a new project with no effort
        vm.prank(recorder);
        ledger.activateProject(1, manager);

        vm.prank(recorder);
        uint256 eff = ledger.recordProfit(1, manager, 1000);

        assertEq(eff, 0);
    }

    // ──────────────────────────────────────
    // Burned M-Effort
    // ──────────────────────────────────────

    function test_burnEffort_marksProjectBurned() public {
        vm.startPrank(recorder);
        ledger.recordEffort(0, manager, SunnaLedger.ActionType.TradeExecuted, keccak256("t1"));
        ledger.recordEffort(0, manager, SunnaLedger.ActionType.ReportSubmitted, keccak256("r1"));
        vm.stopPrank();

        // Total JHD for project: 5 + 10 = 15
        vm.prank(recorder);
        ledger.burnEffort(0, manager);

        SunnaLedger.ProjectEffort memory pe = ledger.getProjectEffort(0);
        assertTrue(pe.burned);
        assertFalse(pe.active);

        (uint256 lifetimeJHD, uint256 burnedJHD,,,,,) = ledger.getManagerStats(manager);
        assertEq(lifetimeJHD, 15);
        assertEq(burnedJHD, 15);
    }

    function test_burnEffort_reducesLifetimeEfficiency() public {
        vm.startPrank(recorder);

        // Project 0: 10 trades = 50 JHD
        for (uint256 i = 0; i < 10; i++) {
            ledger.recordEffort(0, manager, SunnaLedger.ActionType.TradeExecuted, bytes32(i));
        }
        ledger.recordProfit(0, manager, 5000);

        // Project 1: 5 trades = 25 JHD (will be burned)
        ledger.activateProject(1, manager);
        for (uint256 i = 0; i < 5; i++) {
            ledger.recordEffort(1, manager, SunnaLedger.ActionType.TradeExecuted, bytes32(i + 100));
        }
        ledger.burnEffort(1, manager);

        vm.stopPrank();

        (,,,,,, uint256 lifetimeEff) = ledger.getManagerStats(manager);

        // Efficiency = (5000 * 100) / (50 + 25) = 500000 / 75 = 6666
        assertEq(lifetimeEff, 6666);
    }

    // ──────────────────────────────────────
    // Burn Ratio
    // ──────────────────────────────────────

    function test_burnRatio_calculatesCorrectly() public {
        vm.startPrank(recorder);

        // 200 JHD in project 0
        for (uint256 i = 0; i < 40; i++) {
            ledger.recordEffort(0, manager, SunnaLedger.ActionType.TradeExecuted, bytes32(i));
        }

        // 150 JHD in project 1 (will burn)
        ledger.activateProject(1, manager);
        for (uint256 i = 0; i < 30; i++) {
            ledger.recordEffort(1, manager, SunnaLedger.ActionType.TradeExecuted, bytes32(i + 200));
        }
        ledger.burnEffort(1, manager);

        vm.stopPrank();

        // Burn ratio = (150 * 10000) / 350 = 4285 bps ≈ 42.85%
        uint256 ratio = ledger.getBurnRatio(manager);
        assertEq(ratio, 4285);
    }

    // ──────────────────────────────────────
    // Fuzz: JHD Monotonically Increasing
    // ──────────────────────────────────────

    function testFuzz_jhdMonotonicallyIncreasing(uint8 actionCount) public {
        actionCount = uint8(bound(actionCount, 1, 50));

        uint256 previousJHD = 0;

        vm.startPrank(recorder);
        for (uint8 i = 0; i < actionCount; i++) {
            ledger.recordEffort(
                0,
                manager,
                SunnaLedger.ActionType.TradeExecuted,
                bytes32(uint256(i))
            );

            (uint256 currentJHD,,,,,,) = ledger.getManagerStats(manager);
            assertTrue(currentJHD >= previousJHD, "JHD decreased!");
            previousJHD = currentJHD;
        }
        vm.stopPrank();
    }
}
