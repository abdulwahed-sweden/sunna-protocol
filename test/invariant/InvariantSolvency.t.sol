// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/SolvencyGuard.sol";

/// @title Invariant Test — SE-1: Solvency Equilibrium
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Property-based test: after any sequence of valid operations,
///         totalAssets >= totalLiabilities always holds.
///         Uses decreaseAssets (which enforces solvency) instead of reportLoss
///         (which intentionally allows insolvency for loss absorption).
contract InvariantSolvencyTest is Test {
    SolvencyGuard guard;
    SolvencyHandler handler;

    function setUp() public {
        guard = new SolvencyGuard();
        handler = new SolvencyHandler(guard);
        guard.authorizeEngine(address(handler));

        targetContract(address(handler));
    }

    function invariant_assetsAlwaysGreaterOrEqualLiabilities() public view {
        assertTrue(
            guard.totalAssets() >= guard.totalLiabilities(),
            "SE-1 VIOLATED: assets < liabilities"
        );
    }
}

/// @title SolvencyHandler — Invariant test helper
contract SolvencyHandler is Test {
    SolvencyGuard guard;

    constructor(SolvencyGuard _guard) {
        guard = _guard;
    }

    function increaseAssets(uint128 amount) external {
        guard.increaseAssets(amount);
    }

    function setLiabilities(uint128 amount) external {
        if (amount <= guard.totalAssets()) {
            guard.setLiabilities(amount);
        }
    }

    /// @notice Uses decreaseAssets which has a built-in solvency check.
    ///         Will revert internally if it would break SE-1.
    function decreaseAssets(uint128 amount) external {
        if (amount <= guard.totalAssets()) {
            try guard.decreaseAssets(amount) {} catch {}
        }
    }
}
