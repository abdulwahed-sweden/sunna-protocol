// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {SunnaLedger} from "../../src/mudaraba/SunnaLedger.sol";

contract SunnaLedgerTest is Test {
    SunnaLedger ledger;

    address manager = makeAddr("manager");

    function setUp() public {
        ledger = new SunnaLedger();
        ledger.setAuthorizedRecorder(address(this), true);
    }

    // ── recordEffort ─────────────────────────────────────────────────

    function test_recordEffort_tradeExecuted() public {
        bytes32 proofHash = keccak256("trade-proof-1");

        ledger.recordEffort(0, manager, SunnaLedger.ActionType(0), proofHash); // TRADE_EXECUTED

        (uint256 totalJHD,,,,) = ledger.getProjectEffort(0);
        assertEq(totalJHD, 5, "TRADE_EXECUTED should add 5 JHD");
    }

    // ── JHD accumulation ─────────────────────────────────────────────

    function test_jhdAccumulation() public {
        for (uint256 i = 0; i < 5; i++) {
            ledger.recordEffort(
                0,
                manager,
                SunnaLedger.ActionType(0), // TRADE_EXECUTED = 5 JHD each
                keccak256(abi.encodePacked("trade-", i))
            );
        }

        (uint256 totalJHD,,,,) = ledger.getProjectEffort(0);
        assertEq(totalJHD, 25, "5 trades * 5 JHD = 25 JHD total");
    }

    // ── burnEffort ───────────────────────────────────────────────────

    function test_burnEffort() public {
        // Record some effort first
        ledger.recordEffort(0, manager, SunnaLedger.ActionType(0), keccak256("t1")); // 5 JHD
        ledger.recordEffort(0, manager, SunnaLedger.ActionType(1), keccak256("r1")); // 10 JHD
        // totalJHD = 15

        ledger.burnEffort(0, manager, "loss");

        (, , bool burned, ,) = ledger.getProjectEffort(0);
        assertTrue(burned, "project effort should be burned");

        (uint256 totalJHD, uint256 burnedJHD, , , ,) = ledger.getManagerStats(manager);
        assertEq(totalJHD, 15, "totalJHD should remain 15");
        assertEq(burnedJHD, 15, "burnedJHD should equal totalJHD after burn");
    }

    // ── recordProfitAndEfficiency ────────────────────────────────────

    function test_recordProfitAndEfficiency() public {
        // Build up 150 JHD total using various action types:
        // TRADE_EXECUTED (0) = 5 JHD   -> 10 trades  = 50
        // REPORT_SUBMITTED (1) = 10 JHD -> 5 reports = 50
        // STRATEGY_UPDATED (2) = 8 JHD  -> 2 updates = 16
        // PORTFOLIO_REBALANCED (3) = 15 JHD -> 2 rebalances = 30
        // MONITORING_HOUR (4) = 1 JHD -> 4 hours = 4
        // Total = 50 + 50 + 16 + 30 + 4 = 150

        for (uint256 i = 0; i < 10; i++) {
            ledger.recordEffort(0, manager, SunnaLedger.ActionType(0), keccak256(abi.encodePacked("trade", i)));
        }
        for (uint256 i = 0; i < 5; i++) {
            ledger.recordEffort(0, manager, SunnaLedger.ActionType(1), keccak256(abi.encodePacked("report", i)));
        }
        for (uint256 i = 0; i < 2; i++) {
            ledger.recordEffort(0, manager, SunnaLedger.ActionType(2), keccak256(abi.encodePacked("strategy", i)));
        }
        for (uint256 i = 0; i < 2; i++) {
            ledger.recordEffort(0, manager, SunnaLedger.ActionType(3), keccak256(abi.encodePacked("rebalance", i)));
        }
        for (uint256 i = 0; i < 4; i++) {
            ledger.recordEffort(0, manager, SunnaLedger.ActionType(4), keccak256(abi.encodePacked("monitor", i)));
        }

        // Verify 150 JHD accumulated
        (uint256 totalJHD,,,,) = ledger.getProjectEffort(0);
        assertEq(totalJHD, 150, "should have 150 JHD total");

        // Record profit of 2200 USD
        // efficiency = (2200 * 100) / 150 = 1466
        ledger.recordProfitAndEfficiency(0, manager, 2200);

        (, uint256 profitUSD,, uint256 efficiency,) = ledger.getProjectEffort(0);
        assertEq(profitUSD, 2200, "profitUSD mismatch");
        assertEq(efficiency, 1466, "efficiency should be (2200*100)/150 = 1466");
    }

    // ── getManagerStats ──────────────────────────────────────────────

    function test_getManagerStats() public {
        // Project 0: 3 trades = 15 JHD
        for (uint256 i = 0; i < 3; i++) {
            ledger.recordEffort(0, manager, SunnaLedger.ActionType(0), keccak256(abi.encodePacked("p0-", i)));
        }

        // Project 1: 2 reports = 20 JHD
        for (uint256 i = 0; i < 2; i++) {
            ledger.recordEffort(1, manager, SunnaLedger.ActionType(1), keccak256(abi.encodePacked("p1-", i)));
        }

        // Burn project 0 effort
        ledger.burnEffort(0, manager, "project 0 loss");

        (
            uint256 totalJHD,
            uint256 burnedJHD,
            uint256 activeJHD,
            ,
            ,
        ) = ledger.getManagerStats(manager);

        assertEq(totalJHD, 35, "totalJHD = 15 + 20 = 35");
        assertEq(burnedJHD, 15, "burnedJHD = project 0's 15 JHD");
        assertEq(activeJHD, 20, "activeJHD = 35 - 15 = 20");
    }

    // ── access control ───────────────────────────────────────────────

    function test_onlyRecorder_reverts() public {
        address outsider = makeAddr("outsider");

        vm.prank(outsider);
        vm.expectRevert(SunnaLedger.UnauthorizedRecorder.selector);
        ledger.recordEffort(0, manager, SunnaLedger.ActionType(0), keccak256("x"));
    }

    // ── fuzz: JHD monotonically increasing ───────────────────────────

    function testFuzz_jhdMonotonicallyIncreasing(uint8 actionCount) public {
        actionCount = uint8(bound(actionCount, 1, 50));

        uint256 prevJHD = 0;
        for (uint8 i = 0; i < actionCount; i++) {
            // Cycle through action types 0-3 (skip MONITORING_HOUR=4 since weight is 1,
            // still monotonic but let us use all types)
            SunnaLedger.ActionType action = SunnaLedger.ActionType(i % 5);
            ledger.recordEffort(0, manager, action, keccak256(abi.encodePacked("fuzz-", i)));

            (uint256 totalJHD,,,,) = ledger.getProjectEffort(0);
            assertGe(totalJHD, prevJHD, "JHD must only increase");
            assertTrue(totalJHD > prevJHD, "JHD must strictly increase after each record");
            prevJHD = totalJHD;
        }
    }
}
