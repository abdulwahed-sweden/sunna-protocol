// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MudarabaEngine} from "../src/mudaraba/MudarabaEngine.sol";
import {SunnaLedger} from "../src/mudaraba/SunnaLedger.sol";

/// @title SimulateMudaraba — Full Lifecycle Demo on Base Sepolia
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Demonstrates a complete Mudaraba cycle:
///         Sarah (funder) provides $10,000 capital.
///         Marco (manager) provides effort over 6 months.
///         Two scenarios: profit case and loss case.
contract SimulateMudaraba is Script {
    // ──────────────────────────────────────
    // Deployed Contract Addresses (Base Sepolia)
    // ──────────────────────────────────────
    address constant USDC     = 0x1dbc10925A8ea312228E762b523511F59449F6F4;
    address constant ENGINE   = 0x21fbcbB6B22F0745ACa48f2a430C101C847dbDFd;
    address constant LEDGER   = 0x19c214bC8D4168C0f7313bCF780C67063697F9D0;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        MudarabaEngine engine = MudarabaEngine(ENGINE);
        SunnaLedger ledger = SunnaLedger(LEDGER);

        // ══════════════════════════════════════════════════════
        //  CHARACTERS
        //  Sarah — Capital provider (Rabb al-Mal)
        //  Marco — Portfolio manager (Mudarib)
        // ══════════════════════════════════════════════════════
        address sarah = makeAddr("sarah");
        address marco = makeAddr("marco");

        console.log("==============================================");
        console.log("  Sunna Protocol — Mudaraba Simulation");
        console.log("  Author: Abdulwahed Mansour / Sweden");
        console.log("==============================================");
        console.log("");

        // ──────────────────────────────────────
        // STEP 1: Fund Sarah with MockUSDC
        // ──────────────────────────────────────
        uint256 capital = 10_000e6; // 10,000 USDC (6 decimals)

        // Mint USDC to Sarah (deployer has mint rights on MockUSDC)
        (bool ok,) = USDC.call(abi.encodeWithSignature("mint(address,uint256)", sarah, capital));
        require(ok, "Mint failed");

        console.log("STEP 1: Sarah funded with 10,000 USDC");
        console.log("  Sarah balance:", IERC20(USDC).balanceOf(sarah) / 1e6, "USDC");

        // ──────────────────────────────────────
        // STEP 2: Sarah creates a Mudaraba project with Marco
        //         Profit split: 70% Sarah / 30% Marco (7000 / 3000 bps)
        // ──────────────────────────────────────
        vm.stopBroadcast();

        // Sarah approves and creates the project
        vm.startBroadcast(uint256(keccak256(abi.encodePacked("sarah"))));
        IERC20(USDC).approve(ENGINE, capital);
        uint256 projectId = engine.createProject(
            marco,        // manager
            capital,      // 10,000 USDC
            7000,         // Sarah gets 70% of profit
            3000          // Marco gets 30% of profit
        );
        vm.stopBroadcast();

        console.log("");
        console.log("STEP 2: Project created");
        console.log("  Project ID:", projectId);
        console.log("  Capital: 10,000 USDC");
        console.log("  Profit split: Sarah 70% / Marco 30%");
        console.log("  Engine balance:", IERC20(USDC).balanceOf(ENGINE) / 1e6, "USDC");

        // ──────────────────────────────────────
        // STEP 3: Marco works — effort recorded as JHD
        //
        //   Action                  | JHD Weight | Proof
        //   ─────────────────────────┼────────────┼────────────
        //   5 trades executed       | 5 × 5 = 25 | tx hashes
        //   2 reports submitted     | 2 × 10 = 20| IPFS CIDs
        //   1 portfolio rebalance   | 1 × 15 = 15| multi-proof
        //   ─────────────────────────┼────────────┼────────────
        //   TOTAL                   | 60 JHD     |
        // ──────────────────────────────────────
        vm.startBroadcast(deployerKey);

        // Authorize deployer as recorder (already admin)
        ledger.setAuthorizedRecorder(deployer, true);

        // Activate the project for effort tracking
        ledger.activateProject(projectId, marco);

        // Record 5 trade executions (5 JHD each = 25 JHD)
        for (uint256 i = 0; i < 5; i++) {
            ledger.recordEffort(
                projectId,
                marco,
                SunnaLedger.ActionType.TradeExecuted,
                keccak256(abi.encodePacked("trade_", i))
            );
        }

        // Record 2 reports (10 JHD each = 20 JHD)
        for (uint256 i = 0; i < 2; i++) {
            ledger.recordEffort(
                projectId,
                marco,
                SunnaLedger.ActionType.ReportSubmitted,
                keccak256(abi.encodePacked("report_", i))
            );
        }

        // Record 1 portfolio rebalance (15 JHD)
        ledger.recordEffort(
            projectId,
            marco,
            SunnaLedger.ActionType.PortfolioRebalanced,
            keccak256("rebalance_q2")
        );

        vm.stopBroadcast();

        SunnaLedger.ProjectEffort memory effort = ledger.getProjectEffort(projectId);
        console.log("");
        console.log("STEP 3: Marco's effort recorded");
        console.log("  Total JHD:", effort.totalJHD);
        console.log("  Actions recorded:", effort.entryCount);

        // ══════════════════════════════════════════════════════
        //  SCENARIO A: PROFIT — Investment grew to $15,000
        //
        //  Profit = $15,000 - $10,000 = $5,000
        //  Sarah gets: $10,000 (capital) + $3,500 (70% profit) = $13,500
        //  Marco gets: $1,500 (30% profit)
        //  Efficiency: ($5,000 × 100) / 60 JHD = 8,333
        // ══════════════════════════════════════════════════════
        console.log("");
        console.log("==============================================");
        console.log("  SCENARIO A: PROFIT (+50%)");
        console.log("==============================================");

        uint256 finalBalanceProfit = 15_000e6;

        // Simulate profit: mint extra USDC to the engine
        vm.startBroadcast(deployerKey);
        (ok,) = USDC.call(abi.encodeWithSignature(
            "mint(address,uint256)", ENGINE, 5_000e6
        ));
        require(ok, "Profit mint failed");
        vm.stopBroadcast();

        // Marco settles the project (only manager can settle)
        vm.startBroadcast(uint256(keccak256(abi.encodePacked("marco"))));
        engine.settle(projectId, finalBalanceProfit);
        vm.stopBroadcast();

        uint256 sarahFinal = IERC20(USDC).balanceOf(sarah);
        uint256 marcoFinal = IERC20(USDC).balanceOf(marco);

        console.log("");
        console.log("  RESULTS:");
        console.log("  Sarah received:", sarahFinal / 1e6, "USDC");
        console.log("    (Capital: 10,000 + Profit share: 3,500)");
        console.log("  Marco received:", marcoFinal / 1e6, "USDC");
        console.log("    (Profit share: 1,500)");
        console.log("");
        console.log("  Marco's Efficiency: (5000 x 100) / 60 JHD =", (5000 * 100) / 60);

        // ══════════════════════════════════════════════════════
        //  SCENARIO B: LOSS — New project, investment dropped to $8,000
        //
        //  Loss = $10,000 - $8,000 = $2,000
        //  Sarah gets: $8,000 (whatever remains — bears capital loss)
        //  Marco gets: $0 (bears effort loss — Burned M-Effort)
        //  Marco's JHD: BURNED permanently
        // ══════════════════════════════════════════════════════
        console.log("");
        console.log("==============================================");
        console.log("  SCENARIO B: LOSS (-20%)");
        console.log("==============================================");

        // Create a second project for the loss scenario
        vm.startBroadcast(deployerKey);
        (ok,) = USDC.call(abi.encodeWithSignature("mint(address,uint256)", sarah, capital));
        require(ok, "Mint2 failed");
        vm.stopBroadcast();

        vm.startBroadcast(uint256(keccak256(abi.encodePacked("sarah"))));
        IERC20(USDC).approve(ENGINE, capital);
        uint256 projectId2 = engine.createProject(marco, capital, 7000, 3000);
        vm.stopBroadcast();

        // Marco works on project 2 (record effort)
        vm.startBroadcast(deployerKey);
        ledger.activateProject(projectId2, marco);
        for (uint256 i = 0; i < 8; i++) {
            ledger.recordEffort(
                projectId2,
                marco,
                SunnaLedger.ActionType.TradeExecuted,
                keccak256(abi.encodePacked("loss_trade_", i))
            );
        }
        vm.stopBroadcast();

        SunnaLedger.ProjectEffort memory effort2 = ledger.getProjectEffort(projectId2);
        console.log("");
        console.log("  Marco worked hard: ", effort2.totalJHD, "JHD recorded");

        // Settle with loss: final balance = 8,000 USDC
        uint256 sarahBefore = IERC20(USDC).balanceOf(sarah);
        uint256 marcoBefore = IERC20(USDC).balanceOf(marco);

        vm.startBroadcast(uint256(keccak256(abi.encodePacked("marco"))));
        engine.settle(projectId2, 8_000e6);
        vm.stopBroadcast();

        // Burn Marco's effort on the failed project
        vm.startBroadcast(deployerKey);
        ledger.burnEffort(projectId2, marco);
        vm.stopBroadcast();

        uint256 sarahAfterLoss = IERC20(USDC).balanceOf(sarah) - sarahBefore;
        uint256 marcoAfterLoss = IERC20(USDC).balanceOf(marco) - marcoBefore;

        console.log("");
        console.log("  RESULTS (Ghunm bil-Ghurm):");
        console.log("  Sarah received:", sarahAfterLoss / 1e6, "USDC (lost 2,000)");
        console.log("  Marco received:", marcoAfterLoss / 1e6, "USDC (ZERO — effort burned)");

        // ──────────────────────────────────────
        // FINAL: Marco's lifetime stats
        // ──────────────────────────────────────
        (
            uint256 lifetimeJHD,
            uint256 burnedJHD,
            uint256 activeJHD,
            uint256 lifetimeProfit,
            uint256 projectCount,
            uint256 burnedCount,
            uint256 efficiency
        ) = ledger.getManagerStats(marco);

        console.log("");
        console.log("==============================================");
        console.log("  MARCO'S LIFETIME STATS");
        console.log("==============================================");
        console.log("  Total JHD earned:", lifetimeJHD);
        console.log("  JHD burned:", burnedJHD);
        console.log("  Active JHD:", activeJHD);
        console.log("  Projects managed:", projectCount);
        console.log("  Projects burned:", burnedCount);
        console.log("  Lifetime efficiency:", efficiency);

        uint256 burnRatio = ledger.getBurnRatio(marco);
        console.log("  Burn ratio:", burnRatio, "bps (", burnRatio / 100, "% )");

        console.log("");
        console.log("==============================================");
        console.log("  SIMULATION COMPLETE");
        console.log("  Abdulwahed Mansour / Sweden — Invariant Labs");
        console.log("==============================================");
    }

    function makeAddr(string memory name) internal pure returns (address) {
        return vm.addr(uint256(keccak256(abi.encodePacked(name))));
    }
}
