// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {SunnaVault} from "../../src/mudaraba/SunnaVault.sol";
import {SolvencyGuard} from "../../src/core/SolvencyGuard.sol";
import {ShariaGuard} from "../../src/core/ShariaGuard.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock USDT", "mUSDT") {}
    function mint(address to, uint256 a) external { _mint(to, a); }
}

contract SunnaVaultTest is Test {
    SunnaVault vault;
    MockToken token;
    SolvencyGuard solvencyGuard;
    ShariaGuard shariaGuard;

    address user = makeAddr("user");
    address outsider = makeAddr("outsider");

    function setUp() public {
        token = new MockToken();
        solvencyGuard = new SolvencyGuard();
        shariaGuard = new ShariaGuard();

        vault = new SunnaVault(address(token), address(solvencyGuard), address(shariaGuard));

        // Authorize vault as an engine on SolvencyGuard
        solvencyGuard.authorizeEngine(address(vault));

        // Whitelist the token as halal
        shariaGuard.whitelistAsset(address(token), "Test stablecoin");

        token.mint(user, 1_000_000e18);
        token.mint(address(this), 1_000_000e18);

        vm.prank(user);
        token.approve(address(vault), type(uint256).max);

        token.approve(address(vault), type(uint256).max);
    }

    // ── deposit ──────────────────────────────────────────────────────

    function test_deposit() public {
        vm.prank(user);
        vault.deposit(1_000);

        assertEq(vault.deposits(user), 1_000, "deposits[user] should be 1000");
        assertEq(vault.totalDeposits(), 1_000, "totalDeposits should be 1000");
        assertEq(token.balanceOf(address(vault)), 1_000, "vault should hold 1000 tokens");
    }

    // ── withdraw ─────────────────────────────────────────────────────

    function test_withdraw() public {
        vm.prank(user);
        vault.deposit(1_000);

        uint256 balBefore = token.balanceOf(user);

        vm.prank(user);
        vault.withdraw(500);

        assertEq(vault.deposits(user), 500, "deposits[user] should be 500 after withdrawal");
        assertEq(vault.totalDeposits(), 500, "totalDeposits should be 500");
        assertEq(token.balanceOf(user), balBefore + 500, "user should receive 500 tokens back");
    }

    // ── withdraw: insufficient balance ───────────────────────────────

    function test_withdraw_insufficientBalance_reverts() public {
        vm.prank(user);
        vault.deposit(1_000);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(SunnaVault.InsufficientDeposit.selector, 1_001, 1_000)
        );
        vault.withdraw(1_001);
    }

    // ── depositorCount ───────────────────────────────────────────────

    function test_depositorCount() public {
        vm.prank(user);
        vault.deposit(1_000);

        assertEq(vault.depositorCount(), 1, "one depositor");

        vault.deposit(2_000); // address(this) deposits
        assertEq(vault.depositorCount(), 2, "two depositors");
    }

    // ── isConsistent ─────────────────────────────────────────────────

    function test_isConsistent() public {
        vm.prank(user);
        vault.deposit(1_000);
        assertTrue(vault.isConsistent(), "vault should be consistent after deposit");
    }
}
