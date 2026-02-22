// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../src/shield/SunnaShield.sol";

contract MockAsset is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1_000_000e18);
    }
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title SunnaShield Tests — No-Fee-On-Loss Adapter Verification
/// @author Abdulwahed Mansour — Sunna Protocol
contract SunnaShieldTest is Test {
    SunnaShield shield;
    MockAsset asset;
    address engine = makeAddr("engine");

    function setUp() public {
        asset = new MockAsset();
        shield = new SunnaShield(
            IERC20(address(asset)),
            "Shielded USDC",
            "sUSDC",
            engine,
            500 // 5% fee
        );

        // Engine needs tokens for repay
        asset.mint(engine, 1_000_000e18);
        vm.prank(engine);
        asset.approve(address(shield), type(uint256).max);
    }

    // ──────────────────────────────────────
    // Loss Reporting — ZERO fees
    // ──────────────────────────────────────

    function test_reportLoss_zeroFeeMinted() public {
        vm.prank(engine);
        shield.recordInvestment(10_000e18);

        uint256 totalSupplyBefore = shield.totalSupply();

        vm.prank(engine);
        shield.reportLoss(3_000e18);

        // No new shares should have been minted
        assertEq(shield.totalSupply(), totalSupplyBefore, "Shares minted on loss!");
        assertEq(shield.investedAssets(), 7_000e18);
        assertEq(shield.totalReportedLoss(), 3_000e18);
    }

    function test_reportLoss_revertsExceedsInvested() public {
        vm.prank(engine);
        shield.recordInvestment(5_000e18);

        vm.prank(engine);
        vm.expectRevert(abi.encodeWithSelector(
            SunnaShield.LossExceedsInvested.selector, 6_000e18, 5_000e18
        ));
        shield.reportLoss(6_000e18);
    }

    // ──────────────────────────────────────
    // Profit Repayment — fees on profit only
    // ──────────────────────────────────────

    function test_repay_feeOnlyOnProfit() public {
        vm.prank(engine);
        shield.recordInvestment(10_000e18);

        // Seed with a depositor so convertToShares works
        asset.mint(address(this), 1e18);
        asset.approve(address(shield), 1e18);
        shield.deposit(1e18, address(this));

        vm.prank(engine);
        shield.repay(10_000e18, 2_000e18);

        assertEq(shield.totalRealizedProfit(), 2_000e18);
    }

    // ──────────────────────────────────────
    // Access Control
    // ──────────────────────────────────────

    function test_reportLoss_onlyEngine() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert(SunnaShield.OnlyEngine.selector);
        shield.reportLoss(100);
    }

    function test_repay_onlyEngine() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert(SunnaShield.OnlyEngine.selector);
        shield.repay(100, 0);
    }

    // ──────────────────────────────────────
    // Shield Status
    // ──────────────────────────────────────

    function test_shieldStatus_tracksCorrectly() public {
        vm.startPrank(engine);
        shield.recordInvestment(10_000e18);
        shield.reportLoss(2_000e18);
        vm.stopPrank();

        (uint256 invested, uint256 profit, uint256 loss, int256 net) = shield.shieldStatus();
        assertEq(invested, 8_000e18);
        assertEq(profit, 0);
        assertEq(loss, 2_000e18);
        assertEq(net, -2_000e18);
    }

    // ──────────────────────────────────────
    // Fuzz: No Fee On Any Loss Amount
    // ──────────────────────────────────────

    function testFuzz_reportLoss_neverMintsFees(uint128 invested, uint128 loss) public {
        invested = uint128(bound(invested, 1, type(uint64).max));
        loss = uint128(bound(loss, 1, invested));

        vm.prank(engine);
        shield.recordInvestment(invested);

        uint256 supplyBefore = shield.totalSupply();

        vm.prank(engine);
        shield.reportLoss(loss);

        assertEq(shield.totalSupply(), supplyBefore, "PY-1 violated in Shield: shares minted on loss");
    }
}
