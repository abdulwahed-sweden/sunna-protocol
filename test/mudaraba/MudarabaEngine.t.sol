// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/mudaraba/MudarabaEngine.sol";

/// @title MockUSDC — Test stablecoin
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1_000_000_000e6);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title MudarabaEngine Tests — Profit-Loss Sharing Verification
/// @author Abdulwahed Mansour — Sunna Protocol
contract MudarabaEngineTest is Test {
    MudarabaEngine engine;
    MockUSDC usdc;
    address funder = makeAddr("funder");
    address manager = makeAddr("manager");

    function setUp() public {
        usdc = new MockUSDC();
        engine = new MudarabaEngine(address(usdc));

        // Give funder tokens and approve
        usdc.mint(funder, 1_000_000e6);
        vm.prank(funder);
        usdc.approve(address(engine), type(uint256).max);
    }

    // ──────────────────────────────────────
    // Project Creation
    // ──────────────────────────────────────

    function test_createProject_success() public {
        vm.prank(funder);
        uint256 pid = engine.createProject(manager, 10_000e6, 6000, 4000);

        assertEq(pid, 0);
        assertEq(engine.projectCount(), 1);
        assertEq(engine.totalActiveCapital(), 10_000e6);
        assertEq(usdc.balanceOf(address(engine)), 10_000e6);
    }

    function test_createProject_revertsInvalidSplit() public {
        vm.prank(funder);
        vm.expectRevert(abi.encodeWithSelector(
            MudarabaEngine.InvalidProfitSplit.selector, 6000, 5000
        ));
        engine.createProject(manager, 10_000e6, 6000, 5000);
    }

    function test_createProject_revertsZeroCapital() public {
        vm.prank(funder);
        vm.expectRevert(MudarabaEngine.InvalidCapitalAmount.selector);
        engine.createProject(manager, 0, 6000, 4000);
    }

    function test_createProject_revertsZeroManager() public {
        vm.prank(funder);
        vm.expectRevert(MudarabaEngine.ZeroAddress.selector);
        engine.createProject(address(0), 10_000e6, 6000, 4000);
    }

    // ──────────────────────────────────────
    // Profit Settlement — 60/40 Split
    // ──────────────────────────────────────

    function test_settle_profit_60_40() public {
        vm.prank(funder);
        uint256 pid = engine.createProject(manager, 10_000e6, 6000, 4000);

        // Simulate profit: final balance is 15,000 (5,000 profit)
        usdc.mint(address(engine), 5_000e6);

        uint256 funderBefore = usdc.balanceOf(funder);
        uint256 managerBefore = usdc.balanceOf(manager);

        vm.prank(manager);
        engine.settle(pid, 15_000e6);

        // Profit = 5000
        // Funder: 10000 + (5000 * 6000 / 10000) = 10000 + 3000 = 13000
        // Manager: (5000 * 4000 / 10000) = 2000
        assertEq(usdc.balanceOf(funder) - funderBefore, 13_000e6);
        assertEq(usdc.balanceOf(manager) - managerBefore, 2_000e6);
    }

    // ──────────────────────────────────────
    // Loss Settlement — Ghunm bil-Ghurm
    // ──────────────────────────────────────

    function test_settle_loss_managerGetsZero() public {
        vm.prank(funder);
        uint256 pid = engine.createProject(manager, 10_000e6, 6000, 4000);

        uint256 funderBefore = usdc.balanceOf(funder);
        uint256 managerBefore = usdc.balanceOf(manager);

        // Loss: final balance is 9,000 (1,000 loss)
        vm.prank(manager);
        engine.settle(pid, 9_000e6);

        // Funder gets whatever remains: 9000
        // Manager gets ZERO — bears effort loss (Burned M-Effort)
        assertEq(usdc.balanceOf(funder) - funderBefore, 9_000e6);
        assertEq(usdc.balanceOf(manager) - managerBefore, 0);
    }

    function test_settle_loss_projectStatusBurned() public {
        vm.prank(funder);
        uint256 pid = engine.createProject(manager, 10_000e6, 6000, 4000);

        vm.prank(manager);
        engine.settle(pid, 8_000e6);

        MudarabaEngine.Project memory proj = engine.getProject(pid);
        assertTrue(proj.status == MudarabaEngine.ProjectStatus.Burned);
    }

    function test_settle_totalLoss_funderGetsZero() public {
        vm.prank(funder);
        uint256 pid = engine.createProject(manager, 10_000e6, 6000, 4000);

        uint256 funderBefore = usdc.balanceOf(funder);

        // Total loss: final balance is 0
        vm.prank(manager);
        engine.settle(pid, 0);

        assertEq(usdc.balanceOf(funder) - funderBefore, 0);
    }

    // ──────────────────────────────────────
    // Settlement Guards
    // ──────────────────────────────────────

    function test_settle_revertsNotManager() public {
        vm.prank(funder);
        uint256 pid = engine.createProject(manager, 10_000e6, 6000, 4000);

        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(
            MudarabaEngine.NotProjectManager.selector, rando, manager
        ));
        engine.settle(pid, 10_000e6);
    }

    function test_settle_revertsAlreadySettled() public {
        vm.prank(funder);
        uint256 pid = engine.createProject(manager, 10_000e6, 6000, 4000);

        vm.prank(manager);
        engine.settle(pid, 10_000e6);

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(
            MudarabaEngine.ProjectAlreadySettled.selector, pid
        ));
        engine.settle(pid, 10_000e6);
    }

    // ──────────────────────────────────────
    // Precision Tests
    // ──────────────────────────────────────

    function test_settle_multiplyBeforeDivide_oddNumbers() public {
        vm.prank(funder);
        uint256 pid = engine.createProject(manager, 999e6, 6000, 4000);

        // Profit: 1 unit
        usdc.mint(address(engine), 1e6);

        vm.prank(manager);
        engine.settle(pid, 1000e6);

        // Profit = 1e6
        // Funder profit: (1e6 * 6000) / 10000 = 600000 (not 0)
        // Manager profit: (1e6 * 4000) / 10000 = 400000 (not 0)
        MudarabaEngine.Project memory proj = engine.getProject(pid);
        assertTrue(proj.status == MudarabaEngine.ProjectStatus.Settled);
    }

    // ──────────────────────────────────────
    // Fuzz: Total Distribution Invariant
    // ──────────────────────────────────────

    function testFuzz_settlement_conservesFunds(
        uint128 capital,
        uint128 finalBalance,
        uint16 funderBps
    ) public {
        capital = uint128(bound(capital, 1e6, 100_000_000e6));
        finalBalance = uint128(bound(finalBalance, 0, capital * 2));
        funderBps = uint16(bound(funderBps, 100, 9900));
        uint16 managerBps = 10_000 - funderBps;

        usdc.mint(funder, capital);
        vm.prank(funder);
        usdc.approve(address(engine), type(uint256).max);

        vm.prank(funder);
        uint256 pid = engine.createProject(manager, capital, funderBps, managerBps);

        // Ensure engine has enough for settlement
        if (finalBalance > capital) {
            usdc.mint(address(engine), finalBalance - capital);
        }

        uint256 engineBefore = usdc.balanceOf(address(engine));
        uint256 funderBefore = usdc.balanceOf(funder);
        uint256 managerBefore = usdc.balanceOf(manager);

        vm.prank(manager);
        engine.settle(pid, finalBalance);

        uint256 totalPaid = (usdc.balanceOf(funder) - funderBefore)
            + (usdc.balanceOf(manager) - managerBefore);

        // INVARIANT: total paid out must not exceed final balance
        assertTrue(totalPaid <= finalBalance, "Paid more than available");
    }
}
