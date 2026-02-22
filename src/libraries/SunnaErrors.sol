// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SunnaErrors
/// @notice Custom error definitions shared across all Sunna Protocol contracts.
/// @author Abdulwahed Mansour — Sunna Protocol

library SunnaErrors {
    // ──────────────────────────────────────────────
    //  Shield / Vault Errors
    // ──────────────────────────────────────────────

    /// @dev Total assets dropped below total liabilities.
    error SolvencyViolation(uint256 assets, uint256 liabilities);

    /// @dev Caller is not permitted to invoke this function.
    error UnauthorizedCaller();

    /// @dev A performance fee was charged during a loss period.
    error FeeOnLossViolation();

    /// @dev Share amount is zero or otherwise invalid.
    error InvalidShares();

    // ──────────────────────────────────────────────
    //  Mudaraba / Project Errors
    // ──────────────────────────────────────────────

    /// @dev Action requires the project to be settled first.
    error ProjectNotSettled();

    /// @dev The project has already been settled; cannot settle again.
    error ProjectAlreadySettled();

    /// @dev The referenced project does not exist.
    error ProjectDoesNotExist();

    /// @dev JHD (effort-token) amount is zero or invalid.
    error InvalidJHDAmount();

    /// @dev Caller is not an authorised effort recorder.
    error UnauthorizedRecorder();

    // ──────────────────────────────────────────────
    //  Oracle / Price-Feed Errors
    // ──────────────────────────────────────────────

    /// @dev The oracle price data is older than the acceptable staleness window.
    error StalePrice(uint256 updatedAt, uint256 staleness);

    /// @dev The answered-in round does not match the expected round ID.
    error InvalidRound(uint80 answeredInRound, uint80 roundId);

    /// @dev The oracle returned a price of zero.
    error ZeroPrice();

    /// @dev The oracle returned a negative price.
    error NegativePrice();

    // ──────────────────────────────────────────────
    //  General Errors
    // ──────────────────────────────────────────────

    /// @dev Division by zero.
    error ZeroDivision();

    /// @dev A low-level token transfer or ETH send failed.
    error TransferFailed();
}
