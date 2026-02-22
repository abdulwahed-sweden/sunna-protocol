// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SunnaMath
/// @notice Safe multiply-before-divide math utilities for the Sunna Protocol.
/// @dev    All helpers revert on division by zero and intermediate overflow.
/// @author Abdulwahed Mansour — Sunna Protocol

library SunnaMath {
    // ──────────────────────────────────────────────
    //  Custom Errors
    // ──────────────────────────────────────────────

    /// @dev Thrown when the denominator supplied to `mulDiv` is zero.
    error ZeroDivision();

    /// @dev Thrown when the intermediate multiplication overflows uint256.
    error MulDivOverflow();

    // ──────────────────────────────────────────────
    //  Constants
    // ──────────────────────────────────────────────

    /// @dev One basis point denominator (100.00 %).
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    // ──────────────────────────────────────────────
    //  Functions
    // ──────────────────────────────────────────────

    /// @notice Multiply `x` by `y` and then divide by `denominator`,
    ///         performing the multiplication first to prevent precision loss.
    /// @param x           First multiplicand.
    /// @param y           Second multiplicand.
    /// @param denominator The divisor (must be > 0).
    /// @return result     (x * y) / denominator, rounded down.
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        if (denominator == 0) revert ZeroDivision();

        // Use the full 512-bit product so we never lose precision.
        uint256 prod0; // Least-significant 256 bits of the product.
        uint256 prod1; // Most-significant 256 bits of the product.

        assembly {
            let mm := mulmod(x, y, not(0))
            prod0 := mul(x, y)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // If the product fits in 256 bits we can short-circuit.
        if (prod1 == 0) {
            return prod0 / denominator;
        }

        // The product must not overflow 512 bits relative to denominator.
        if (prod1 >= denominator) revert MulDivOverflow();

        // 512-bit division using Knuth long division.
        uint256 remainder;
        assembly {
            remainder := mulmod(x, y, denominator)
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        uint256 twos = denominator & (~denominator + 1);
        assembly {
            denominator := div(denominator, twos)
            prod0 := div(prod0, twos)
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        uint256 inverse = (3 * denominator) ^ 2;
        inverse *= 2 - denominator * inverse;
        inverse *= 2 - denominator * inverse;
        inverse *= 2 - denominator * inverse;
        inverse *= 2 - denominator * inverse;
        inverse *= 2 - denominator * inverse;
        inverse *= 2 - denominator * inverse;

        result = prod0 * inverse;
    }

    /// @notice Return `amount` scaled by `bps` basis points.
    /// @dev    Equivalent to `amount * bps / 10_000` but overflow-safe.
    /// @param amount The base value.
    /// @param bps    Basis points (1 bps = 0.01 %).
    /// @return The proportional value.
    function bpsOf(uint256 amount, uint16 bps) internal pure returns (uint256) {
        return mulDiv(amount, uint256(bps), BPS_DENOMINATOR);
    }
}
