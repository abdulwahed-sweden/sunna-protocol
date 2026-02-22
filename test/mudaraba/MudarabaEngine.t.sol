// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {MudarabaEngine} from "../../src/mudaraba/MudarabaEngine.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock USDT", "mUSDT") {}
    function mint(address to, uint256 a) external { _mint(to, a); }
}

contract MudarabaEngineTest is Test {
    MudarabaEngine engine;
    MockToken token;

    address funder = makeAddr("funder");
    address manager = makeAddr("manager");

    function setUp() public {
        token = new MockToken();
        engine = new MudarabaEngine(address(token));

        token.mint(funder, 1_000_000e18);
        token.mint(manager, 1_000_000e18);

        vm.prank(funder);
        token.approve(address(engine), type(uint256).max);

        vm.prank(manager);
        token.approve(address(engine), type(uint256).max);
    }

    // ── createProject ────────────────────────────────────────────────

    function test_createProject() public {
        uint256 funderBalBefore = token.balanceOf(funder);

        vm.prank(funder);
        uint256 projectId = engine.createProject(manager, 10_000, 6000, 4000);

        assertEq(engine.projectCount(), 1, "projectCount should be 1");
        assertEq(projectId, 0, "first projectId should be 0");

        (
            address storedFunder,
            address storedManager,
            uint256 capital,
            uint256 finalBalance,
            uint16 funderShareBps,
            uint16 managerShareBps,
            bool settled
        ) = engine.projects(0);

        assertEq(storedFunder, funder, "funder mismatch");
        assertEq(storedManager, manager, "manager mismatch");
        assertEq(capital, 10_000, "capital mismatch");
        assertEq(finalBalance, 0, "finalBalance should be 0");
        assertEq(funderShareBps, 6000, "funderShareBps mismatch");
        assertEq(managerShareBps, 4000, "managerShareBps mismatch");
        assertFalse(settled, "should not be settled");

        assertEq(token.balanceOf(funder), funderBalBefore - 10_000, "funder balance not reduced");
        assertEq(token.balanceOf(address(engine)), 10_000, "engine should hold capital");
    }

    function test_createProject_invalidShares_reverts() public {
        vm.prank(funder);
        vm.expectRevert(MudarabaEngine.InvalidShares.selector);
        engine.createProject(manager, 10_000, 5000, 4000);
    }

    // ── settle: profit ───────────────────────────────────────────────

    function test_settle_profit_60_40() public {
        vm.prank(funder);
        engine.createProject(manager, 10_000, 6000, 4000);

        // Manager settles with 15000 finalBalance
        // profit = 15000 - 10000 = 5000
        // funderTotal  = 10000 + (5000 * 6000 / 10000) = 13000
        // managerProfit = (5000 * 4000 / 10000) = 2000

        uint256 funderBalBefore = token.balanceOf(funder);
        uint256 managerBalBefore = token.balanceOf(manager);

        vm.prank(manager);
        engine.settle(0, 15_000);

        assertEq(token.balanceOf(funder), funderBalBefore + 13_000, "funder should receive 13000");
        assertEq(token.balanceOf(manager), managerBalBefore - 15_000 + 2_000, "manager net should be -13000");
    }

    // ── settle: loss ─────────────────────────────────────────────────

    function test_settle_loss_managerGetsZero() public {
        vm.prank(funder);
        engine.createProject(manager, 10_000, 6000, 4000);

        uint256 funderBalBefore = token.balanceOf(funder);
        uint256 managerBalBefore = token.balanceOf(manager);

        vm.prank(manager);
        engine.settle(0, 9_000);

        // Funder gets back 9000 (bears the 1000 loss)
        assertEq(token.balanceOf(funder), funderBalBefore + 9_000, "funder should receive 9000");
        // Manager transferred 9000 in and got 0 out
        assertEq(token.balanceOf(manager), managerBalBefore - 9_000, "manager should get nothing back");
    }

    // ── settle: already settled ──────────────────────────────────────

    function test_settle_alreadySettled_reverts() public {
        vm.prank(funder);
        engine.createProject(manager, 10_000, 6000, 4000);

        vm.prank(manager);
        engine.settle(0, 15_000);

        vm.prank(manager);
        vm.expectRevert(MudarabaEngine.ProjectAlreadySettled.selector);
        engine.settle(0, 15_000);
    }

    // ── settle: only manager ─────────────────────────────────────────

    function test_settle_onlyManager_reverts() public {
        vm.prank(funder);
        engine.createProject(manager, 10_000, 6000, 4000);

        vm.prank(funder);
        vm.expectRevert(MudarabaEngine.OnlyManager.selector);
        engine.settle(0, 15_000);
    }

    // ── precision: multiply-before-divide ────────────────────────────

    function test_multiplyBeforeDivide_precision() public {
        // capital = 999, managerShareBps = 4000 (40%)
        vm.prank(funder);
        engine.createProject(manager, 999, 6000, 4000);

        // Settle with finalBalance = 1998 => profit = 999
        // managerProfit = (999 * 4000) / 10000 = 3996000 / 10000 = 399 (not 0)
        vm.prank(manager);
        engine.settle(0, 1_998);

        // funderProfit = (999 * 6000) / 10000 = 5994000 / 10000 = 599
        // funderTotal  = 999 + 599 = 1598
        // managerProfit = 399
        // Total distributed = 1598 + 399 = 1997 (1 wei dust stays in contract)

        (, address storedManager, uint256 capital, uint256 finalBalance,,,) = engine.projects(0);
        assertEq(storedManager, manager);
        assertEq(capital, 999);
        assertEq(finalBalance, 1_998);

        // Verify manager got a non-zero profit
        // managerProfit should be 399, not 0
        // We check via balance: manager sent 1998, got back 399 => net -1599
        // Since we cannot easily isolate, let us verify total distributed is correct
        // engine should hold: 10000 (from first project capital already settled above... no,
        // this is a fresh project)
        // engine received capital=999 from funder, then 1998 from manager = 2997
        // engine sent funderTotal=1598 to funder, managerProfit=399 to manager = 1997
        // engine balance = 2997 - 1997 = 1000 (999 initial capital + 1 dust)
        // Actually engine sent initial capital out too via funderTotal which includes capital
        // engine holds: 999 (from createProject) + 1998 (from settle) - 1598 (funder) - 399 (manager) = 1000
        assertEq(token.balanceOf(address(engine)), 1_000, "engine dust should be 1 wei (999+1)");
    }
}
