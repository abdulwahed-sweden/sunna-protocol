// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SunnaEvents — Centralized Event Definitions
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice All events emitted across the Sunna Protocol ecosystem.
///         Centralized for indexing consistency and off-chain monitoring.
/// @custom:security-contact abdulwahed.mansour@protonmail.com

// ═══════════════════════════════════════════════════════════════════
//  Sunna Protocol — Event Library
//  Authored by Abdulwahed Mansour / Sweden — February 2026
//
//  Every state change must leave a permanent, auditable trace.
//
//  Abdulwahed Mansour / Sweden — Invariant Labs
// ═══════════════════════════════════════════════════════════════════

// ──────────────────────────────────────
// Solvency Events
// ──────────────────────────────────────

/// @notice Emitted when solvency is checked.
/// @param assets Total protocol assets at time of check.
/// @param liabilities Total protocol liabilities at time of check.
/// @param solvent Whether the protocol is solvent.
event SolvencyChecked(uint256 assets, uint256 liabilities, bool solvent);

/// @notice Emitted when a loss is reported and absorbed.
/// @param amount The loss amount absorbed.
/// @param remainingAssets Assets remaining after loss absorption.
event LossAbsorbed(uint256 amount, uint256 remainingAssets);

// ──────────────────────────────────────
// Fee Events
// ──────────────────────────────────────

/// @notice Emitted when fees are collected into the Takaful buffer.
/// @param amount Fee amount collected.
/// @param totalBuffered Total fees currently held in escrow.
event FeesBuffered(uint256 amount, uint256 totalBuffered);

/// @notice Emitted when buffered fees are released after solvency confirmation.
/// @param recipient Address receiving the released fees.
/// @param amount Amount released.
event FeesReleased(address indexed recipient, uint256 amount);

/// @notice Emitted when fee extraction is blocked due to active deficit.
/// @param attemptedAmount The fee amount that was blocked.
/// @param currentDeficit The deficit that prevented extraction.
event FeeExtractionBlocked(uint256 attemptedAmount, uint256 currentDeficit);

// ──────────────────────────────────────
// Mudaraba Events
// ──────────────────────────────────────

/// @notice Emitted when a new Mudaraba project is created.
/// @param projectId Unique identifier for the project.
/// @param funder Address of the capital provider.
/// @param manager Address of the effort provider (Mudarib).
/// @param capital Initial capital committed.
/// @param funderShareBps Funder's profit share in basis points.
event ProjectCreated(
    uint256 indexed projectId,
    address indexed funder,
    address indexed manager,
    uint256 capital,
    uint16 funderShareBps
);

/// @notice Emitted when a project is settled (profit or loss).
/// @param projectId The settled project.
/// @param finalBalance The final balance at settlement.
/// @param netProfit Net profit (zero if loss occurred).
/// @param funderPayout Amount paid to the funder.
/// @param managerPayout Amount paid to the manager (zero on loss).
event ProjectSettled(
    uint256 indexed projectId,
    uint256 finalBalance,
    uint256 netProfit,
    uint256 funderPayout,
    uint256 managerPayout
);

// ──────────────────────────────────────
// SunnaLedger (JHD) Events
// ──────────────────────────────────────

/// @notice Emitted when effort is recorded for a manager.
/// @param projectId The project this effort belongs to.
/// @param manager The manager who performed the action.
/// @param jhdAmount JHD units credited.
/// @param actionType The type of action performed.
/// @param proofHash On-chain proof reference (tx hash, IPFS CID, etc.).
event EffortRecorded(
    uint256 indexed projectId,
    address indexed manager,
    uint256 jhdAmount,
    uint8 actionType,
    bytes32 proofHash
);

/// @notice Emitted when a manager's effort on a project is burned.
/// @param projectId The failed project.
/// @param manager The manager whose effort was burned.
/// @param burnedJHD Total JHD burned for this project.
event EffortBurned(
    uint256 indexed projectId,
    address indexed manager,
    uint256 burnedJHD
);

/// @notice Emitted when efficiency is calculated for a project.
/// @param projectId The project evaluated.
/// @param manager The manager evaluated.
/// @param totalJHD Total effort spent.
/// @param profitUSD Profit in base asset denomination.
/// @param efficiency Efficiency score: (profit * 100) / jhd.
event EfficiencyCalculated(
    uint256 indexed projectId,
    address indexed manager,
    uint256 totalJHD,
    uint256 profitUSD,
    uint256 efficiency
);

// ──────────────────────────────────────
// Sharia Guard Events
// ──────────────────────────────────────

/// @notice Emitted when an asset is added to the halal whitelist.
/// @param asset The whitelisted asset address.
event AssetWhitelisted(address indexed asset);

/// @notice Emitted when an asset is removed from the halal whitelist.
/// @param asset The removed asset address.
event AssetDelisted(address indexed asset);

// ──────────────────────────────────────
// Shield Events
// ──────────────────────────────────────

/// @notice Emitted when profit is realized through the shield adapter.
/// @param principal Principal amount returned.
/// @param profit Profit amount realized.
/// @param feeShares Fee shares minted to the engine.
event ProfitRealized(uint256 principal, uint256 profit, uint256 feeShares);

/// @notice Emitted when a loss is reported through the shield adapter.
/// @param lossAmount The loss amount. Zero fees are minted — by design.
event ShieldLossReported(uint256 lossAmount);
