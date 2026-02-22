// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SunnaMath — Financial Mathematics Library
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Safe arithmetic operations designed for financial calculations.
///         All operations enforce multiply-before-divide ordering to prevent
///         precision loss in integer arithmetic.
/// @custom:security-contact abdulwahed.mansour@protonmail.com

library SunnaMath {
    // ═══════════════════════════════════════════════════════════════
    //  Sunna Protocol — Financial Math Library
    //  Authored by Abdulwahed Mansour / Sweden — February 2026
    //
    //  Core principle: In integer arithmetic, (a * b) / c ≠ (a / c) * b
    //  We ALWAYS multiply first, then divide. This is not optimization —
    //  it is a correctness requirement. A single reversed operation can
    //  cause silent loss of funds across thousands of transactions.
    //
    //  This library exists because "close enough" is not acceptable
    //  when people's money is at stake.
    //
    //  Abdulwahed Mansour / Sweden — Invariant Labs
    // ═══════════════════════════════════════════════════════════════

    uint256 internal constant BPS_DENOMINATOR = 10_000;

    /// @notice Calculate a basis-point share of an amount.
    /// @dev Multiply before divide: (amount * bps) / 10000.
    ///      Reverts on overflow (Solidity 0.8+ default).
    /// @param amount The base amount.
    /// @param bps Basis points (e.g., 6000 = 60%).
    /// @return result The proportional share.
    function bpsOf(uint256 amount, uint256 bps) internal pure returns (uint256 result) {
        result = (amount * bps) / BPS_DENOMINATOR;
    }

    /// @notice Calculate profit from a final balance and original capital.
    /// @dev Returns zero if finalBalance <= capital (loss case).
    ///      This is the core Sunna formula: P = max(0, R - L).
    /// @param finalBalance The balance after the investment period.
    /// @param capital The original capital committed.
    /// @return profit Net profit, or zero if loss occurred.
    function profitOrZero(uint256 finalBalance, uint256 capital) internal pure returns (uint256 profit) {
        // The Sunna formula: profit exists only when final exceeds original.
        // On loss, profit is exactly zero — never negative, never phantom.
        profit = finalBalance > capital ? finalBalance - capital : 0;
    }

    /// @notice Safe subtraction that returns zero instead of reverting on underflow.
    /// @param a The minuend.
    /// @param b The subtrahend.
    /// @return result a - b, or zero if b > a.
    function saturatingSub(uint256 a, uint256 b) internal pure returns (uint256 result) {
        result = a >= b ? a - b : 0;
    }

    /// @notice Calculate efficiency ratio: (profit * 100) / effort.
    /// @dev Returns zero if effort is zero to prevent division by zero.
    ///      Designed for `using SunnaMath for uint256` pattern:
    ///      `totalJHD.efficiency(profitUSD)` → (profitUSD * 100) / totalJHD.
    /// @param totalJHD The total effort units spent (self via using-for).
    /// @param profitUSD The profit in base denomination.
    /// @return The efficiency score (profit per 100 JHD).
    function efficiency(uint256 totalJHD, uint256 profitUSD) internal pure returns (uint256) {
        if (totalJHD == 0) return 0;
        return (profitUSD * 100) / totalJHD;
    }
}
