// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SunnaErrors — Centralized Error Definitions
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice All custom errors for the Sunna Protocol ecosystem.
///         Centralized for consistency, gas efficiency, and auditability.
/// @custom:security-contact abdulwahed.mansour@protonmail.com

// ═══════════════════════════════════════════════════════════════════
//  Sunna Protocol — Custom Error Library
//  Authored by Abdulwahed Mansour / Sweden — February 2026
//
//  Errors are the first line of defense. Name them well.
//
//  Abdulwahed Mansour / Sweden — Invariant Labs
// ═══════════════════════════════════════════════════════════════════

// ──────────────────────────────────────
// Solvency & Constitutional Errors
// ──────────────────────────────────────

/// @notice Thrown when an operation would cause assets to fall below liabilities.
/// @param assets Current total assets.
/// @param liabilities Current total liabilities.
error SolvencyViolation(uint256 assets, uint256 liabilities);

/// @notice Thrown when fee extraction is attempted during an active deficit.
error FeeExtractionDuringDeficit();

/// @notice Thrown when governance attempts to modify a constitutional invariant.
error ConstitutionalOverrideAttempt();

/// @notice Thrown when a protected parameter modification is attempted.
/// @param parameter The name hash of the parameter.
error ProtectedParameterModification(bytes32 parameter);

// ──────────────────────────────────────
// Access Control Errors
// ──────────────────────────────────────

/// @notice Thrown when a caller lacks the required role.
/// @param caller The address that attempted the call.
/// @param requiredRole The role that was required.
error UnauthorizedRole(address caller, bytes32 requiredRole);

/// @notice Thrown when only the designated engine contract may call.
error OnlyEngine();

/// @notice Thrown when only the admin may call.
error OnlyAdmin();

/// @notice Thrown when a zero address is provided where a valid address is required.
error ZeroAddress();

// ──────────────────────────────────────
// Mudaraba Engine Errors
// ──────────────────────────────────────

/// @notice Thrown when profit-sharing basis points do not sum to 10,000.
/// @param funderBps The funder's basis points.
/// @param managerBps The manager's basis points.
error InvalidProfitSplit(uint16 funderBps, uint16 managerBps);

/// @notice Thrown when an operation targets an already-settled project.
/// @param projectId The project that was already settled.
error ProjectAlreadySettled(uint256 projectId);

/// @notice Thrown when an operation targets a project that does not exist.
/// @param projectId The non-existent project ID.
error ProjectNotFound(uint256 projectId);

/// @notice Thrown when a non-manager attempts a manager-only action.
/// @param caller The unauthorized caller.
/// @param expectedManager The project's designated manager.
error NotProjectManager(address caller, address expectedManager);

/// @notice Thrown when capital amount is zero or invalid.
error InvalidCapitalAmount();

/// @notice Thrown when the final balance exceeds what the contract holds.
/// @param claimed The claimed final balance.
/// @param available The actual available balance.
error InsufficientSettlementBalance(uint256 claimed, uint256 available);

// ──────────────────────────────────────
// SunnaLedger (JHD) Errors
// ──────────────────────────────────────

/// @notice Thrown when a non-authorized recorder attempts to log effort.
error UnauthorizedRecorder();

/// @notice Thrown when JHD weight resolves to zero for an action type.
error ZeroJHDWeight();

/// @notice Thrown when effort is recorded for a settled/burned project.
/// @param projectId The project that is no longer active.
error ProjectNotActive(uint256 projectId);

// ──────────────────────────────────────
// Oracle Errors
// ──────────────────────────────────────

/// @notice Thrown when oracle returns a zero or negative price.
error InvalidOraclePrice();

/// @notice Thrown when oracle data is stale beyond the acceptable threshold.
/// @param updatedAt The timestamp of the last oracle update.
/// @param maxStaleness The maximum acceptable staleness in seconds.
error StaleOracleData(uint256 updatedAt, uint256 maxStaleness);

/// @notice Thrown when oracle round data is incomplete.
/// @param answeredInRound The round in which the answer was computed.
/// @param roundId The round that was queried.
error IncompleteOracleRound(uint80 answeredInRound, uint80 roundId);

// ──────────────────────────────────────
// Sharia Guard Errors
// ──────────────────────────────────────

/// @notice Thrown when an asset is not on the halal whitelist.
/// @param asset The non-whitelisted asset address.
error AssetNotHalal(address asset);

/// @notice Thrown when a protocol is not on the approved list.
/// @param protocol The non-approved protocol address.
error ProtocolNotApproved(address protocol);

// ──────────────────────────────────────
// Shield (Adapter) Errors
// ──────────────────────────────────────

/// @notice Thrown when reported loss exceeds invested assets.
/// @param reported The reported loss amount.
/// @param invested The total invested assets.
error LossExceedsInvested(uint256 reported, uint256 invested);
