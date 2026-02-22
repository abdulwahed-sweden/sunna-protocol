// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SunnaShield} from "../../src/shield/SunnaShield.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {}
    function mint(address to, uint256 a) external { _mint(to, a); }
}

contract SunnaShieldTest is Test {
    SunnaShield public shield;
    MockToken public token;

    address public user = makeAddr("user");

    function setUp() public {
        token = new MockToken();
        shield = new SunnaShield(
            IERC20(address(token)),
            "Sunna Shield",
            "sSHD",
            address(this),  // test contract is the engine
            500              // 5% fee in basis points
        );
        // Mint tokens to this contract (engine) and user
        token.mint(address(this), 1_000_000e18);
        token.mint(user, 1_000_000e18);

        // Approve shield from engine
        token.approve(address(shield), type(uint256).max);

        // Approve shield from user
        vm.prank(user);
        token.approve(address(shield), type(uint256).max);
    }

    // ─── deposit ───────────────────────────────────────────────

    function test_deposit() public {
        uint256 depositAmount = 1000e18;

        vm.prank(user);
        uint256 shares = shield.deposit(depositAmount, user);

        assertGt(shares, 0, "shares should be > 0");
        assertEq(shield.balanceOf(user), shares, "user share balance mismatch");
        assertEq(shield.investedAssets(), depositAmount, "investedAssets mismatch");
    }

    // ─── reportLoss — no fee shares minted ─────────────────────

    function test_reportLoss_noFeeMinted() public {
        // Deposit 1000 tokens from user
        vm.prank(user);
        shield.deposit(1000e18, user);

        uint256 engineSharesBefore = shield.balanceOf(address(this));

        // Engine reports a loss of 500
        shield.reportLoss(500e18);

        uint256 engineSharesAfter = shield.balanceOf(address(this));

        assertEq(engineSharesAfter, engineSharesBefore, "no fee shares should be minted on loss");
        assertEq(shield.investedAssets(), 500e18, "investedAssets should decrease by loss");
    }

    // ─── repay with profit — fees minted ───────────────────────

    function test_repay_withProfit_mintsFees() public {
        // Deposit 1000 tokens from user
        vm.prank(user);
        shield.deposit(1000e18, user);

        uint256 engineSharesBefore = shield.balanceOf(address(this));

        // Engine repays principal 1000 + profit 200
        // Fee = 200 * 500 / 10000 = 10 tokens worth of shares
        shield.repay(1000e18, 200e18);

        uint256 engineSharesAfter = shield.balanceOf(address(this));
        uint256 feeSharesMinted = engineSharesAfter - engineSharesBefore;

        assertGt(feeSharesMinted, 0, "fee shares should be minted on profit");

        // The fee in asset terms should be ~10 tokens (200 * 500 / 10000)
        uint256 feeAssets = shield.convertToAssets(feeSharesMinted);
        assertApproxEqAbs(feeAssets, 10e18, 0.1e18, "fee assets should be ~10 tokens");
    }

    // ─── repay with zero profit — no fees ──────────────────────

    function test_repay_zeroProfit_noFees() public {
        // Deposit 1000 tokens from user
        vm.prank(user);
        shield.deposit(1000e18, user);

        uint256 engineSharesBefore = shield.balanceOf(address(this));

        // Engine repays principal 1000 with zero profit
        shield.repay(1000e18, 0);

        uint256 engineSharesAfter = shield.balanceOf(address(this));

        assertEq(engineSharesAfter, engineSharesBefore, "no fee shares should be minted on zero profit");
    }

    // ─── reportLoss reverts on excess ──────────────────────────

    function test_reportLoss_revertsOnExcess() public {
        // Deposit 100 tokens from user
        vm.prank(user);
        shield.deposit(100e18, user);

        // Attempt to report loss greater than invested
        vm.expectRevert("SUNNA: loss > invested");
        shield.reportLoss(200e18);
    }

    // ─── onlyEngine — reportLoss reverts for non-engine ────────

    function test_onlyEngine_reportLoss_reverts() public {
        // Deposit 100 tokens from user
        vm.prank(user);
        shield.deposit(100e18, user);

        // Random address tries to report loss
        vm.prank(makeAddr("attacker"));
        vm.expectRevert(SunnaShield.UnauthorizedEngine.selector);
        shield.reportLoss(50e18);
    }

    // ─── fuzz: no fee on any loss ──────────────────────────────

    function testFuzz_noFeeOnAnyLoss(uint256 lossAmount) public {
        uint256 depositAmount = 10_000e18;

        vm.prank(user);
        shield.deposit(depositAmount, user);

        lossAmount = bound(lossAmount, 1, shield.investedAssets());

        uint256 engineSharesBefore = shield.balanceOf(address(this));

        shield.reportLoss(lossAmount);

        uint256 engineSharesAfter = shield.balanceOf(address(this));

        assertEq(engineSharesAfter, engineSharesBefore, "no fee shares should ever be minted on loss");
    }
}
