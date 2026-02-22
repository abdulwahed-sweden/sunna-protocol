// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MudarabaEngine} from "../src/mudaraba/MudarabaEngine.sol";
import {SunnaLedger} from "../src/mudaraba/SunnaLedger.sol";

/// @title SimulateMudaraba - Full Lifecycle Demo on Base Sepolia
/// @author Abdulwahed Mansour - Sunna Protocol
contract SimulateMudaraba is Script {
    // Deployed Contract Addresses (Base Sepolia)
    address constant USDC   = 0x1dbc10925A8ea312228E762b523511F59449F6F4;
    address constant ENGINE = 0x21fbcbB6B22F0745ACa48f2a430C101C847dbDFd;
    address constant LEDGER = 0x19c214bC8D4168C0f7313bCF780C67063697F9D0;

    // Deterministic keys
    uint256 constant SARAH_KEY = uint256(keccak256(abi.encodePacked("sarah")));
    uint256 constant MARCO_KEY = uint256(keccak256(abi.encodePacked("marco")));

    uint256 constant CAPITAL = 10_000 ether; // 10,000 mUSDC (18 decimals)

    MudarabaEngine engine = MudarabaEngine(ENGINE);
    SunnaLedger ledger = SunnaLedger(LEDGER);

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address sarah = vm.addr(SARAH_KEY);
        address marco = vm.addr(MARCO_KEY);

        console.log("==============================================");
        console.log("  Sunna Protocol - Mudaraba Simulation");
        console.log("  Author: Abdulwahed Mansour / Sweden");
        console.log("==============================================");
        console.log("  Sarah (funder):", sarah);
        console.log("  Marco (manager):", marco);

        _step0_fund(deployerKey, sarah, marco);
        uint256 pid1 = _step1_createProject(sarah, marco);
        _step2_recordEffort(deployerKey, pid1, marco);
        _step3_settleProfit(deployerKey, pid1, sarah, marco);
        uint256 pid2 = _step4_lossProject(deployerKey, sarah, marco);
        _step5_printStats(marco);
    }

    function _step0_fund(uint256 deployerKey, address sarah, address marco) internal {
        vm.startBroadcast(deployerKey);
        payable(sarah).transfer(0.001 ether);
        payable(marco).transfer(0.001 ether);
        IERC20(USDC).transfer(sarah, CAPITAL * 2);
        ledger.setAuthorizedRecorder(vm.addr(deployerKey), true);
        vm.stopBroadcast();

        console.log("");
        console.log("STEP 0: Funded participants");
        console.log("  Sarah mUSDC:", IERC20(USDC).balanceOf(sarah));
        console.log("  Marco ETH:", marco.balance);
    }

    function _step1_createProject(address sarah, address marco) internal returns (uint256 projectId) {
        vm.startBroadcast(SARAH_KEY);
        IERC20(USDC).approve(ENGINE, CAPITAL);
        projectId = engine.createProject(marco, CAPITAL, 7000, 3000);
        vm.stopBroadcast();

        console.log("");
        console.log("STEP 1: Project created");
        console.log("  Project ID:", projectId);
        console.log("  Capital: 10,000 mUSDC");
        console.log("  Split: Sarah 70% / Marco 30%");
    }

    function _step2_recordEffort(uint256 deployerKey, uint256 projectId, address marco) internal {
        vm.startBroadcast(deployerKey);

        ledger.activateProject(projectId, marco);

        for (uint256 i = 0; i < 5; i++) {
            ledger.recordEffort(projectId, marco, SunnaLedger.ActionType.TradeExecuted, keccak256(abi.encodePacked("trade_", i)));
        }
        for (uint256 i = 0; i < 2; i++) {
            ledger.recordEffort(projectId, marco, SunnaLedger.ActionType.ReportSubmitted, keccak256(abi.encodePacked("report_", i)));
        }
        ledger.recordEffort(projectId, marco, SunnaLedger.ActionType.PortfolioRebalanced, keccak256("rebalance_q2"));

        vm.stopBroadcast();

        SunnaLedger.ProjectEffort memory eff = ledger.getProjectEffort(projectId);
        console.log("");
        console.log("STEP 2: Marco's effort recorded");
        console.log("  Total JHD:", eff.totalJHD);
        console.log("  Actions:", eff.entryCount);
    }

    function _step3_settleProfit(uint256 deployerKey, uint256 projectId, address sarah, address marco) internal {
        console.log("");
        console.log("==============================================");
        console.log("  SCENARIO A: PROFIT (+50%)");
        console.log("==============================================");

        uint256 profit = 5_000 ether;

        // Deployer sends extra USDC to engine to simulate investment growth
        vm.startBroadcast(deployerKey);
        IERC20(USDC).transfer(ENGINE, profit);
        vm.stopBroadcast();

        // Marco settles (only manager can settle)
        vm.startBroadcast(MARCO_KEY);
        engine.settle(projectId, CAPITAL + profit);
        vm.stopBroadcast();

        console.log("  Sarah balance:", IERC20(USDC).balanceOf(sarah));
        console.log("  Marco balance:", IERC20(USDC).balanceOf(marco));

        SunnaLedger.ProjectEffort memory eff = ledger.getProjectEffort(projectId);
        uint256 effScore = (uint256(5000) * 100) / eff.totalJHD;
        console.log("  Efficiency: (5000 x 100) / 60 =", effScore);
    }

    function _step4_lossProject(uint256 deployerKey, address sarah, address marco) internal returns (uint256 projectId2) {
        console.log("");
        console.log("==============================================");
        console.log("  SCENARIO B: LOSS (-20%)");
        console.log("==============================================");

        // Sarah creates second project
        vm.startBroadcast(SARAH_KEY);
        IERC20(USDC).approve(ENGINE, CAPITAL);
        projectId2 = engine.createProject(marco, CAPITAL, 7000, 3000);
        vm.stopBroadcast();

        // Record effort on project 2
        vm.startBroadcast(deployerKey);
        ledger.activateProject(projectId2, marco);
        for (uint256 i = 0; i < 8; i++) {
            ledger.recordEffort(projectId2, marco, SunnaLedger.ActionType.TradeExecuted, keccak256(abi.encodePacked("loss_trade_", i)));
        }
        vm.stopBroadcast();

        uint256 sarahBefore = IERC20(USDC).balanceOf(sarah);
        uint256 marcoBefore = IERC20(USDC).balanceOf(marco);

        // Marco settles with loss
        vm.startBroadcast(MARCO_KEY);
        engine.settle(projectId2, 8_000 ether);
        vm.stopBroadcast();

        // Burn Marco's effort
        vm.startBroadcast(deployerKey);
        ledger.burnEffort(projectId2, marco);
        vm.stopBroadcast();

        console.log("  Sarah received:", IERC20(USDC).balanceOf(sarah) - sarahBefore);
        console.log("  Marco received:", IERC20(USDC).balanceOf(marco) - marcoBefore);
        console.log("  (Marco gets ZERO - effort burned)");
    }

    function _step5_printStats(address marco) internal view {
        (
            uint256 lifetimeJHD,
            uint256 burnedJHD,
            uint256 activeJHD,
            ,
            uint256 projectCount,
            uint256 burnedCount,
            uint256 efficiency
        ) = ledger.getManagerStats(marco);

        console.log("");
        console.log("==============================================");
        console.log("  MARCO'S LIFETIME STATS");
        console.log("==============================================");
        console.log("  Total JHD:", lifetimeJHD);
        console.log("  Burned JHD:", burnedJHD);
        console.log("  Active JHD:", activeJHD);
        console.log("  Projects:", projectCount);
        console.log("  Burned:", burnedCount);
        console.log("  Efficiency:", efficiency);
        console.log("  Burn ratio (bps):", ledger.getBurnRatio(marco));
        console.log("");
        console.log("==============================================");
        console.log("  SIMULATION COMPLETE");
        console.log("  Abdulwahed Mansour / Sweden - Invariant Labs");
        console.log("==============================================");
    }
}
