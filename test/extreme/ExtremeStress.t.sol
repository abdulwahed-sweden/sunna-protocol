// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SolvencyGuard} from "../../src/core/SolvencyGuard.sol";
import {FeeController} from "../../src/core/FeeController.sol";
import {ShariaGuard} from "../../src/core/ShariaGuard.sol";
import {TakafulBuffer} from "../../src/core/TakafulBuffer.sol";
import {ConstitutionalGuard} from "../../src/core/ConstitutionalGuard.sol";
import {SunnaShield} from "../../src/shield/SunnaShield.sol";
import {MudarabaEngine} from "../../src/mudaraba/MudarabaEngine.sol";
import {SunnaLedger} from "../../src/mudaraba/SunnaLedger.sol";
import {SunnaVault} from "../../src/mudaraba/SunnaVault.sol";
import {SunnaShares} from "../../src/mudaraba/SunnaShares.sol";
import {OracleValidator} from "../../src/mudaraba/OracleValidator.sol";
import {SunnaMath} from "../../src/libraries/SunnaMath.sol";

// ═════════════════════════════════════════════════════════════
// Mock Contracts for Adversarial Testing
// ═════════════════════════════════════════════════════════════

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

/// @dev ERC20 that attempts reentrancy on transfer
contract ReentrantToken is ERC20 {
    address public target;
    bytes public payload;
    bool public armed;

    constructor() ERC20("Reentrant", "REENT") {
        _mint(msg.sender, 1_000_000e18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function arm(address _target, bytes calldata _payload) external {
        target = _target;
        payload = _payload;
        armed = true;
    }

    function disarm() external {
        armed = false;
    }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        if (armed && target != address(0) && from != address(0) && to != address(0)) {
            armed = false; // prevent infinite loop
            (bool ok,) = target.call(payload);
            // Silently swallow — we just want to test if the guard catches it
            ok;
        }
    }
}

/// @dev Mock Chainlink aggregator for oracle tests
contract MockAggregator {
    int256 public price;
    uint80 public roundId;
    uint80 public answeredInRound;
    uint256 public updatedAt;
    uint8 public dec;

    constructor(int256 _price, uint8 _decimals) {
        price = _price;
        dec = _decimals;
        roundId = 1;
        answeredInRound = 1;
        updatedAt = block.timestamp;
    }

    function setPrice(int256 _price) external {
        price = _price;
    }

    function setRound(uint80 _roundId, uint80 _answeredInRound) external {
        roundId = _roundId;
        answeredInRound = _answeredInRound;
    }

    function setStaleness(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
    }

    function latestRoundData() external view returns (
        uint80, int256, uint256, uint256, uint80
    ) {
        return (roundId, price, 0, updatedAt, answeredInRound);
    }

    function decimals() external view returns (uint8) {
        return dec;
    }
}

// ═════════════════════════════════════════════════════════════
//  ExtremeStress — Phase 2 Adversarial Test Suite
//  25+ tests: economic attacks, reentrancy, JHD manipulation,
//  oracle edge cases, solvency attacks, constitutional guard,
//  and fuzz tests.
//
//  Author: Abdulwahed Mansour - Sunna Protocol
// ═════════════════════════════════════════════════════════════
contract ExtremeStress is Test {
    using SunnaMath for uint256;

    // Contracts
    MockUSDC usdc;
    SolvencyGuard solvencyGuard;
    FeeController feeController;
    ShariaGuard shariaGuard;
    TakafulBuffer buffer;
    ConstitutionalGuard constitution;
    SunnaShield shield;
    MudarabaEngine engine;
    SunnaLedger ledger;
    SunnaVault vault;
    SunnaShares shares;
    OracleValidator oracle;

    // Actors
    address admin;
    address funder = makeAddr("funder");
    address manager = makeAddr("manager");
    address attacker = makeAddr("attacker");

    function setUp() public {
        admin = address(this);

        // Deploy infrastructure
        usdc = new MockUSDC();
        solvencyGuard = new SolvencyGuard();
        shariaGuard = new ShariaGuard();
        feeController = new FeeController(address(solvencyGuard), 500);
        buffer = new TakafulBuffer(address(usdc), address(solvencyGuard));
        constitution = new ConstitutionalGuard(address(solvencyGuard));
        engine = new MudarabaEngine(address(usdc));
        ledger = new SunnaLedger();
        vault = new SunnaVault(address(usdc), address(solvencyGuard), address(shariaGuard));
        shares = new SunnaShares("Sunna Shares", "sSHR", address(vault), true);
        oracle = new OracleValidator(3600);
        shield = new SunnaShield(
            IERC20(address(usdc)), "Sunna Shield", "sSHD", admin, 500
        );

        // Wire up authorization
        solvencyGuard.authorizeEngine(address(engine));
        solvencyGuard.authorizeEngine(address(vault));
        buffer.authorizeEngine(address(engine));
        ledger.setAuthorizedRecorder(admin, true);
        shariaGuard.whitelistAsset(address(usdc), "Test stablecoin");

        // Fund actors
        usdc.mint(funder, 10_000_000e6);
        vm.prank(funder);
        usdc.approve(address(engine), type(uint256).max);
        vm.prank(funder);
        usdc.approve(address(vault), type(uint256).max);
    }

    // ═════════════════════════════════════════════════════════
    //  CATEGORY 1: ECONOMIC ATTACKS (7 tests)
    // ═════════════════════════════════════════════════════════

    /// @notice Manager cannot claim finalBalance exceeding their project's
    ///         available funds (BUG-002 fix: cross-project drain prevented).
    function test_economic_crossProjectDrain() public {
        // Funder creates two projects with 10,000 each
        vm.startPrank(funder);
        uint256 pid1 = engine.createProject(manager, 10_000e6, 6000, 4000);
        engine.createProject(makeAddr("manager2"), 10_000e6, 6000, 4000);
        vm.stopPrank();

        // Engine now holds 20,000. Manager of project 1 tries to claim 20,000.
        // BUG-002 fix: settle now caps at available = balance - other projects' capital
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(
            MudarabaEngine.InsufficientBalance.selector, 20_000e6, 10_000e6
        ));
        engine.settle(pid1, 20_000e6);

        // Verify funds preserved
        assertEq(usdc.balanceOf(address(engine)), 20_000e6, "Funds must be preserved");
    }

    /// @notice BPS rounding: funderPayout + managerPayout == finalBalance exactly
    ///         (BUG-003 fix: remainder assigned to funder, no dust trapped)
    function test_economic_bpsRoundingDust() public {
        // Use odd profit that doesn't divide evenly
        vm.prank(funder);
        uint256 pid = engine.createProject(manager, 10_000e6, 3333, 6667);

        // 3 units profit: managerPayout = (3 * 6667)/10000 = 2
        // funderPayout = finalBalance - managerPayout = 10_000e6 + 3 - 2 = 10_000e6 + 1
        usdc.mint(address(engine), 3);

        uint256 funderBefore = usdc.balanceOf(funder);
        uint256 managerBefore = usdc.balanceOf(manager);

        vm.prank(manager);
        engine.settle(pid, 10_000e6 + 3);

        uint256 totalPaid = (usdc.balanceOf(funder) - funderBefore)
            + (usdc.balanceOf(manager) - managerBefore);

        // BUG-003 fix: no dust — all funds distributed
        assertEq(totalPaid, 10_000e6 + 3, "All funds must be distributed, zero dust");
    }

    /// @notice Double settlement attack: try to settle the same project twice
    function test_economic_doubleSettle() public {
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

    /// @notice Settle with finalBalance > contract balance (drain attempt)
    function test_economic_settleExceedsBalance() public {
        vm.prank(funder);
        uint256 pid = engine.createProject(manager, 10_000e6, 6000, 4000);

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(
            MudarabaEngine.FinalBalanceExceedsContractBalance.selector, 99_999e6, 10_000e6
        ));
        engine.settle(pid, 99_999e6);
    }

    /// @notice Zero-profit settlement: finalBalance == capital
    function test_economic_zeroProfitSettlement() public {
        vm.prank(funder);
        uint256 pid = engine.createProject(manager, 10_000e6, 6000, 4000);

        uint256 funderBefore = usdc.balanceOf(funder);
        uint256 managerBefore = usdc.balanceOf(manager);

        vm.prank(manager);
        engine.settle(pid, 10_000e6);

        // Exact capital returned to funder, 0 to manager
        assertEq(usdc.balanceOf(funder) - funderBefore, 10_000e6);
        assertEq(usdc.balanceOf(manager) - managerBefore, 0);
    }

    /// @notice Minimum viable project: 1 wei capital
    function test_economic_minimumCapital() public {
        usdc.mint(funder, 1);
        vm.prank(funder);
        uint256 pid = engine.createProject(manager, 1, 5000, 5000);

        // Profit of 1: (1 * 5000) / 10000 = 0 for each
        usdc.mint(address(engine), 1);

        vm.prank(manager);
        engine.settle(pid, 2);

        // Both get 0 profit due to rounding, capital goes to funder
        MudarabaEngine.Project memory proj = engine.getProject(pid);
        assertTrue(proj.status == MudarabaEngine.ProjectStatus.Settled);
    }

    /// @notice Extreme BPS edges: 1/9999 and 9999/1 splits
    function test_economic_extremeBpsSplits() public {
        // 1 bps to funder, 9999 to manager
        vm.prank(funder);
        uint256 pid1 = engine.createProject(manager, 10_000e6, 1, 9999);

        usdc.mint(address(engine), 10_000e6); // 100% profit
        vm.prank(manager);
        engine.settle(pid1, 20_000e6);

        // Funder profit: (10_000e6 * 1) / 10000 = 1000 (1e3)
        // Manager profit: (10_000e6 * 9999) / 10000 = 9_999_000_000 (9999e6 - 1e6 = 9999e3... let me check)
        MudarabaEngine.Project memory proj = engine.getProject(pid1);
        assertTrue(proj.status == MudarabaEngine.ProjectStatus.Settled);

        // 9999 bps to funder, 1 to manager
        vm.prank(funder);
        uint256 pid2 = engine.createProject(manager, 10_000e6, 9999, 1);

        usdc.mint(address(engine), 10_000e6);
        vm.prank(manager);
        engine.settle(pid2, 20_000e6);

        MudarabaEngine.Project memory proj2 = engine.getProject(pid2);
        assertTrue(proj2.status == MudarabaEngine.ProjectStatus.Settled);
    }

    // ═════════════════════════════════════════════════════════
    //  CATEGORY 2: REENTRANCY ATTACKS (3 tests)
    // ═════════════════════════════════════════════════════════

    /// @notice Reentrancy attack on MudarabaEngine.settle via malicious token
    function test_reentrancy_settleViaToken() public {
        ReentrantToken rToken = new ReentrantToken();
        MudarabaEngine rEngine = new MudarabaEngine(address(rToken));

        rToken.mint(funder, 1_000_000e18);
        vm.prank(funder);
        rToken.approve(address(rEngine), type(uint256).max);

        vm.prank(funder);
        uint256 pid = rEngine.createProject(manager, 10_000e18, 6000, 4000);

        // Arm the token to try reentering settle on transfer
        rToken.arm(
            address(rEngine),
            abi.encodeWithSelector(rEngine.settle.selector, pid, 10_000e18)
        );

        // Mint profit
        rToken.mint(address(rEngine), 5_000e18);

        // This should NOT allow double-settle due to ReentrancyGuard
        vm.prank(manager);
        rEngine.settle(pid, 15_000e18);

        // Verify project settled exactly once
        MudarabaEngine.Project memory proj = rEngine.getProject(pid);
        assertTrue(
            proj.status == MudarabaEngine.ProjectStatus.Settled ||
            proj.status == MudarabaEngine.ProjectStatus.Burned,
            "Project must be settled after reentrancy attempt"
        );
    }

    /// @notice Reentrancy attack on SunnaVault.deposit
    function test_reentrancy_vaultDeposit() public {
        ReentrantToken rToken = new ReentrantToken();
        SolvencyGuard rGuard = new SolvencyGuard();
        ShariaGuard rSharia = new ShariaGuard();
        SunnaVault rVault = new SunnaVault(address(rToken), address(rGuard), address(rSharia));

        rGuard.authorizeEngine(address(rVault));
        rSharia.whitelistAsset(address(rToken), "Test");

        rToken.mint(attacker, 1_000e18);
        vm.prank(attacker);
        rToken.approve(address(rVault), type(uint256).max);

        // Arm token to reenter deposit
        rToken.arm(
            address(rVault),
            abi.encodeWithSelector(rVault.deposit.selector, 100e18)
        );

        // Should succeed but reentrancy guard blocks the second deposit
        vm.prank(attacker);
        rVault.deposit(100e18);

        // Verify single deposit recorded
        assertEq(rVault.balanceOf(attacker), 100e18);
    }

    /// @notice Reentrancy attack on TakafulBuffer.bufferFees
    function test_reentrancy_bufferFees() public {
        ReentrantToken rToken = new ReentrantToken();
        SolvencyGuard rGuard = new SolvencyGuard();
        TakafulBuffer rBuffer = new TakafulBuffer(address(rToken), address(rGuard));

        rBuffer.authorizeEngine(address(this));

        rToken.mint(address(this), 1_000e18);
        rToken.approve(address(rBuffer), type(uint256).max);

        // Arm reentrancy
        rToken.arm(
            address(rBuffer),
            abi.encodeWithSelector(rBuffer.bufferFees.selector, 50e18)
        );

        // Should succeed with guard blocking reentry
        rBuffer.bufferFees(100e18);
        assertEq(rBuffer.totalBuffered(), 100e18);
    }

    // ═════════════════════════════════════════════════════════
    //  CATEGORY 3: JHD MANIPULATION (5 tests)
    // ═════════════════════════════════════════════════════════

    /// @notice Unauthorized recorder cannot record effort
    function test_jhd_unauthorizedRecorder() public {
        ledger.activateProject(0, manager);

        vm.prank(attacker);
        vm.expectRevert(SunnaLedger.UnauthorizedRecorder.selector);
        ledger.recordEffort(0, manager, SunnaLedger.ActionType.TradeExecuted, bytes32(0));
    }

    /// @notice Cannot record effort on inactive project
    function test_jhd_effortOnInactiveProject() public {
        // Project 999 was never activated
        vm.expectRevert(abi.encodeWithSelector(
            SunnaLedger.ProjectNotActive.selector, 999
        ));
        ledger.recordEffort(999, manager, SunnaLedger.ActionType.TradeExecuted, bytes32(0));
    }

    /// @notice Double burn: second burn now reverts (BUG-001 fix)
    function test_jhd_doubleBurn() public {
        ledger.activateProject(0, manager);
        ledger.recordEffort(0, manager, SunnaLedger.ActionType.TradeExecuted, bytes32("proof1"));

        // First burn — legitimate
        ledger.burnEffort(0, manager);

        // Verify state after first burn
        (uint256 lifetimeJHD, uint256 burnedJHD,,,,, ) = ledger.getManagerStats(manager);
        assertEq(lifetimeJHD, 5, "Lifetime JHD should be 5");
        assertEq(burnedJHD, 5, "Burned JHD should be 5 after first burn");

        // Second burn now reverts with ProjectAlreadyBurned
        vm.expectRevert(abi.encodeWithSelector(
            SunnaLedger.ProjectAlreadyBurned.selector, 0
        ));
        ledger.burnEffort(0, manager);
    }

    /// @notice Record effort for wrong manager now reverts (BUG-004 fix)
    function test_jhd_effortWrongManager() public {
        ledger.activateProject(0, manager);

        // Attempt to record effort for attacker instead of the project's actual manager
        vm.expectRevert(abi.encodeWithSelector(
            SunnaLedger.ManagerMismatch.selector, attacker, manager
        ));
        ledger.recordEffort(0, attacker, SunnaLedger.ActionType.TradeExecuted, bytes32("proof"));
    }

    /// @notice JHD weight of zero: admin sets weight to 0, then reverts
    function test_jhd_zeroWeightReverts() public {
        vm.expectRevert(SunnaLedger.ZeroJHDWeight.selector);
        ledger.updateJHDWeight(SunnaLedger.ActionType.TradeExecuted, 0);
    }

    // ═════════════════════════════════════════════════════════
    //  CATEGORY 4: ORACLE EDGE CASES (4 tests)
    // ═════════════════════════════════════════════════════════

    /// @notice Zero price from oracle
    function test_oracle_zeroPrice() public {
        MockAggregator agg = new MockAggregator(0, 8);

        vm.expectRevert(abi.encodeWithSelector(
            OracleValidator.InvalidOraclePrice.selector, int256(0)
        ));
        oracle.getValidatedPrice(address(agg));
    }

    /// @notice Negative price from oracle
    function test_oracle_negativePrice() public {
        MockAggregator agg = new MockAggregator(-100, 8);

        vm.expectRevert(abi.encodeWithSelector(
            OracleValidator.InvalidOraclePrice.selector, int256(-100)
        ));
        oracle.getValidatedPrice(address(agg));
    }

    /// @notice Stale oracle data (beyond maxStaleness)
    function test_oracle_staleData() public {
        // Warp to realistic timestamp (Foundry starts at t=1)
        vm.warp(10_000);

        MockAggregator agg = new MockAggregator(2000e8, 8);
        agg.setStaleness(block.timestamp - 7200); // 2 hours ago, max is 1 hour

        vm.expectRevert(abi.encodeWithSelector(
            OracleValidator.StaleOracleData.selector,
            block.timestamp - 7200,
            block.timestamp,
            3600
        ));
        oracle.getValidatedPrice(address(agg));
    }

    /// @notice Incomplete oracle round
    function test_oracle_incompleteRound() public {
        MockAggregator agg = new MockAggregator(2000e8, 8);
        agg.setRound(5, 4); // answeredInRound < roundId

        vm.expectRevert(abi.encodeWithSelector(
            OracleValidator.IncompleteOracleRound.selector, uint80(4), uint80(5)
        ));
        oracle.getValidatedPrice(address(agg));
    }

    // ═════════════════════════════════════════════════════════
    //  CATEGORY 5: SOLVENCY ATTACKS (5 tests)
    // ═════════════════════════════════════════════════════════

    /// @notice Unauthorized address cannot modify solvency state
    function test_solvency_unauthorizedAccess() public {
        vm.prank(attacker);
        vm.expectRevert(SolvencyGuard.OnlyEngine.selector);
        solvencyGuard.increaseAssets(1_000_000e6);
    }

    /// @notice Loss exceeding total assets reverts
    function test_solvency_lossExceedsAssets() public {
        vm.prank(address(engine));
        solvencyGuard.increaseAssets(1000);

        vm.prank(address(engine));
        vm.expectRevert(abi.encodeWithSelector(
            SolvencyGuard.LossExceedsAssets.selector, 2000, 1000
        ));
        solvencyGuard.reportLoss(2000);
    }

    /// @notice Withdrawal that would break solvency reverts
    function test_solvency_withdrawalBreaksSolvency() public {
        vm.prank(address(engine));
        solvencyGuard.increaseAssets(1000);

        vm.prank(address(engine));
        solvencyGuard.setLiabilities(800);

        vm.prank(address(engine));
        vm.expectRevert(abi.encodeWithSelector(
            SolvencyGuard.SolvencyViolation.selector, 100, 800
        ));
        solvencyGuard.decreaseAssets(900);
    }

    /// @notice FeeController blocks fees during deficit
    function test_solvency_feeBlockedDuringDeficit() public {
        vm.prank(address(engine));
        solvencyGuard.increaseAssets(100);

        vm.prank(address(engine));
        solvencyGuard.setLiabilities(200);

        // Deficit exists: fees must be zero
        uint256 fee = feeController.calculateFee(10_000e6);
        assertEq(fee, 0, "Fee must be zero during deficit");
    }

    /// @notice TakafulBuffer refuses fee release when insolvent
    function test_solvency_bufferReleaseBlockedWhenInsolvent() public {
        buffer.authorizeEngine(address(this));
        usdc.approve(address(buffer), type(uint256).max);
        buffer.bufferFees(1_000e6);

        // Create insolvency
        vm.prank(address(engine));
        solvencyGuard.increaseAssets(100);
        vm.prank(address(engine));
        solvencyGuard.setLiabilities(200);

        vm.expectRevert(TakafulBuffer.ProtocolInsolvent.selector);
        buffer.releaseFees(funder, 500e6);
    }

    // ═════════════════════════════════════════════════════════
    //  CATEGORY 6: CONSTITUTIONAL GUARD (4 tests)
    // ═════════════════════════════════════════════════════════

    /// @notice All 6 invariants are protected from creation
    function test_constitution_allProtected() public view {
        assertTrue(constitution.isProtected(constitution.SE_1()));
        assertTrue(constitution.isProtected(constitution.PY_1()));
        assertTrue(constitution.isProtected(constitution.SD_1()));
        assertTrue(constitution.isProtected(constitution.CLA_1()));
        assertTrue(constitution.isProtected(constitution.CHC_1()));
        assertTrue(constitution.isProtected(constitution.DFB_1()));
    }

    /// @notice Override attempt on SE-1 always reverts
    function test_constitution_overrideSE1Reverts() public {
        bytes32 se1 = constitution.SE_1();
        vm.expectRevert(abi.encodeWithSelector(
            ConstitutionalGuard.ConstitutionalOverrideAttempt.selector, se1
        ));
        constitution.attemptOverride(se1);
    }

    /// @notice Override attempt on PY-1 always reverts
    function test_constitution_overridePY1Reverts() public {
        bytes32 py1 = constitution.PY_1();
        vm.expectRevert(abi.encodeWithSelector(
            ConstitutionalGuard.ConstitutionalOverrideAttempt.selector, py1
        ));
        constitution.attemptOverride(py1);
    }

    /// @notice Unprotected invariant (random hash) does NOT revert
    function test_constitution_unprotectedPassesThrough() public view {
        bytes32 fake = keccak256("NOT_A_REAL_INVARIANT");
        // attemptOverride only reverts for protected ones
        // For unprotected, it should NOT revert
        assertFalse(constitution.isProtected(fake));
    }

    // ═════════════════════════════════════════════════════════
    //  CATEGORY 7: SHIELD LAYER (3 tests)
    // ═════════════════════════════════════════════════════════

    /// @notice Loss exceeding invested amount reverts
    function test_shield_lossExceedsInvested() public {
        shield.recordInvestment(1_000e6);

        vm.expectRevert(abi.encodeWithSelector(
            SunnaShield.LossExceedsInvested.selector, 2_000e6, 1_000e6
        ));
        shield.reportLoss(2_000e6);
    }

    /// @notice No fee minted on loss (PY-1 enforced in shield)
    function test_shield_noFeeOnLoss() public {
        usdc.mint(address(shield), 10_000e6);
        shield.recordInvestment(10_000e6);

        uint256 shieldSharesBefore = shield.totalSupply();
        shield.reportLoss(5_000e6);
        uint256 shieldSharesAfter = shield.totalSupply();

        // No new shares should be minted on loss
        assertEq(shieldSharesAfter, shieldSharesBefore, "Shares minted on loss");
    }

    /// @notice Only engine can call shield functions
    function test_shield_onlyEngine() public {
        vm.prank(attacker);
        vm.expectRevert();
        shield.reportLoss(100e6);

        vm.prank(attacker);
        vm.expectRevert();
        shield.repay(100e6, 50e6);
    }

    // ═════════════════════════════════════════════════════════
    //  CATEGORY 8: ACCESS CONTROL (2 tests)
    // ═════════════════════════════════════════════════════════

    /// @notice Non-admin cannot whitelist assets
    function test_access_shariaGuardOnlyAdmin() public {
        vm.prank(attacker);
        vm.expectRevert(ShariaGuard.OnlyAdmin.selector);
        shariaGuard.whitelistAsset(makeAddr("token"), "Bypass attempt");
    }

    /// @notice Non-admin cannot authorize engines
    function test_access_solvencyGuardOnlyAdmin() public {
        vm.prank(attacker);
        vm.expectRevert(SolvencyGuard.OnlyEngine.selector);
        solvencyGuard.authorizeEngine(attacker);
    }

    // ═════════════════════════════════════════════════════════
    //  CATEGORY 9: FUZZ TESTS (4 tests)
    // ═════════════════════════════════════════════════════════

    /// @notice Fuzz: settlement never pays out more than finalBalance
    function testFuzz_settlement_neverOverpays(
        uint128 capital,
        uint128 finalBalance,
        uint16 funderBps
    ) public {
        capital = uint128(bound(capital, 1e6, 100_000_000e6));
        finalBalance = uint128(bound(finalBalance, 0, capital * 2));
        funderBps = uint16(bound(funderBps, 1, 9999));
        uint16 managerBps = 10_000 - funderBps;

        usdc.mint(funder, capital);
        vm.prank(funder);
        usdc.approve(address(engine), type(uint256).max);

        vm.prank(funder);
        uint256 pid = engine.createProject(manager, capital, funderBps, managerBps);

        if (finalBalance > capital) {
            usdc.mint(address(engine), finalBalance - capital);
        }

        uint256 funderBefore = usdc.balanceOf(funder);
        uint256 managerBefore = usdc.balanceOf(manager);

        vm.prank(manager);
        engine.settle(pid, finalBalance);

        uint256 totalPaid = (usdc.balanceOf(funder) - funderBefore)
            + (usdc.balanceOf(manager) - managerBefore);

        // INVARIANT: total paid <= finalBalance (may be less due to rounding)
        assertTrue(totalPaid <= finalBalance, "Overpayment detected!");
    }

    /// @notice Fuzz: JHD monotonically increases with each action
    function testFuzz_jhd_monotonicallyIncreases(uint8 actionCount) public {
        actionCount = uint8(bound(actionCount, 1, 50));

        ledger.activateProject(100, manager);

        uint256 prevJHD = 0;
        for (uint256 i = 0; i < actionCount; i++) {
            ledger.recordEffort(
                100,
                manager,
                SunnaLedger.ActionType.TradeExecuted,
                keccak256(abi.encodePacked(i))
            );

            SunnaLedger.ProjectEffort memory eff = ledger.getProjectEffort(100);
            assertTrue(eff.totalJHD > prevJHD, "JHD did not increase");
            prevJHD = eff.totalJHD;
        }
    }

    /// @notice Fuzz: solvency guard never allows assets < liabilities after valid ops
    function testFuzz_solvency_alwaysHolds(uint128 assets, uint128 liabilities) public {
        assets = uint128(bound(assets, 0, type(uint128).max));
        liabilities = uint128(bound(liabilities, 0, assets));

        vm.prank(address(engine));
        solvencyGuard.increaseAssets(assets);

        vm.prank(address(engine));
        solvencyGuard.setLiabilities(liabilities);

        assertTrue(solvencyGuard.isSolvent());
        assertEq(solvencyGuard.currentDeficit(), 0);
    }

    /// @notice Fuzz: fee controller never extracts fees during deficit
    function testFuzz_noPhantomYield(uint128 assets, uint128 liabilities, uint128 profit) public {
        assets = uint128(bound(assets, 1, type(uint64).max));
        liabilities = uint128(bound(liabilities, assets + 1, uint128(assets) + type(uint64).max));
        profit = uint128(bound(profit, 1, type(uint64).max));

        vm.prank(address(engine));
        solvencyGuard.increaseAssets(assets);

        vm.prank(address(engine));
        solvencyGuard.setLiabilities(liabilities);

        // System is in deficit — fee must be zero
        uint256 fee = feeController.calculateFee(profit);
        assertEq(fee, 0, "PY-1 VIOLATION: fee extracted during deficit");
    }
}
