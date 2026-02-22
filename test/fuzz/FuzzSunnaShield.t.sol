// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/shield/SunnaShield.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {}
    function mint(address to, uint256 a) external { _mint(to, a); }
}

/// @title FuzzSunnaShield — Random Deposit/Withdraw/Loss Tests
/// @author Abdulwahed Mansour
contract FuzzSunnaShieldTest is Test {
    SunnaShield public shield;
    MockToken public token;
    address public user = address(0x1);

    function setUp() public {
        token = new MockToken();
        shield = new SunnaShield(
            IERC20(address(token)),
            "Sunna Shield",
            "sSHD",
            address(this), // engine
            500 // 5% fee
        );
    }

    /// @notice Fuzz: reportLoss must never mint fee shares
    function testFuzz_noFeeOnAnyLoss(uint256 depositAmount, uint256 lossAmount) public {
        depositAmount = bound(depositAmount, 1e6, 1e24);

        // Deposit first
        token.mint(user, depositAmount);
        vm.startPrank(user);
        token.approve(address(shield), depositAmount);
        shield.deposit(depositAmount, user);
        vm.stopPrank();

        // Record investment so investedAssets > 0
        shield.recordInvestment(depositAmount);

        lossAmount = bound(lossAmount, 1, shield.investedAssets());

        uint256 engineSharesBefore = shield.balanceOf(address(this));
        shield.reportLoss(lossAmount);
        uint256 engineSharesAfter = shield.balanceOf(address(this));

        assertEq(engineSharesAfter, engineSharesBefore, "NO FEE ON LOSS: fee shares minted during loss");
    }

    /// @notice Fuzz: deposit then full repay with profit should mint fee shares when fee > 0
    function testFuzz_feeOnProfit(uint256 depositAmount, uint256 profitAmount) public {
        depositAmount = bound(depositAmount, 1e6, 1e24);
        // Ensure profit is large enough so fee shares round to at least 1
        uint256 minProfit = depositAmount / 100;
        if (minProfit < 200) minProfit = 200;
        profitAmount = bound(profitAmount, minProfit, depositAmount);

        // Deposit
        token.mint(user, depositAmount);
        vm.startPrank(user);
        token.approve(address(shield), depositAmount);
        shield.deposit(depositAmount, user);
        vm.stopPrank();

        // Record investment so investedAssets >= depositAmount
        shield.recordInvestment(depositAmount);

        // Engine (this) needs tokens for repay
        token.mint(address(this), depositAmount + profitAmount);
        token.approve(address(shield), depositAmount + profitAmount);

        shield.repay(depositAmount, profitAmount);

        // Fee shares should be minted to engine
        uint256 engineShares = shield.balanceOf(address(this));
        assertTrue(engineShares > 0, "Fee shares should be minted on profit");
    }
}
