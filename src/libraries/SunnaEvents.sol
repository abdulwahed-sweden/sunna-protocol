// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SunnaEvents
/// @notice Event definitions shared across all Sunna Protocol contracts.
/// @author Abdulwahed Mansour — Sunna Protocol

library SunnaEvents {
    // ──────────────────────────────────────────────
    //  Shield / Vault Events
    // ──────────────────────────────────────────────

    /// @dev Emitted after every solvency invariant check.
    /// @param assets      Current total assets held by the vault.
    /// @param liabilities Current total liabilities (shares owed).
    /// @param solvent     Whether assets >= liabilities.
    event SolvencyChecked(uint256 assets, uint256 liabilities, bool solvent);

    /// @dev Emitted when a loss is reported against vault assets.
    /// @param amount          The size of the loss.
    /// @param remainingAssets Assets remaining after the loss.
    event LossReported(uint256 amount, uint256 remainingAssets);

    /// @dev Emitted when profit is realised and fees are minted.
    /// @param principal The original principal amount.
    /// @param profit    The profit earned above principal.
    /// @param feeShares Number of fee shares minted to the treasury.
    event ProfitRealized(uint256 principal, uint256 profit, uint256 feeShares);

    // ──────────────────────────────────────────────
    //  Mudaraba / Project Events
    // ──────────────────────────────────────────────

    /// @dev Emitted when a new Mudaraba project is created.
    /// @param projectId Unique identifier for the project.
    /// @param funder    Address of the capital provider (Rabb al-Mal).
    /// @param manager   Address of the working partner (Mudarib).
    /// @param capital   Initial capital committed to the project.
    event ProjectCreated(
        uint256 indexed projectId,
        address funder,
        address manager,
        uint256 capital
    );

    /// @dev Emitted when a project is settled and proceeds are distributed.
    /// @param projectId    Unique identifier for the project.
    /// @param finalBalance Total balance at settlement.
    /// @param profit       Net profit (or zero if a loss occurred).
    /// @param funderShare  Amount returned to the funder.
    /// @param managerShare Amount paid to the manager.
    event ProjectSettled(
        uint256 indexed projectId,
        uint256 finalBalance,
        uint256 profit,
        uint256 funderShare,
        uint256 managerShare
    );

    // ──────────────────────────────────────────────
    //  Effort / JHD Events
    // ──────────────────────────────────────────────

    /// @dev Emitted when a manager records a unit of effort (JHD token mint).
    /// @param projectId  The project the effort is attributed to.
    /// @param manager    The manager who performed the effort.
    /// @param jhdAmount  JHD tokens minted for this action.
    /// @param actionType Numeric code identifying the type of effort.
    /// @param proofHash  Keccak-256 hash of the off-chain proof artefact.
    event EffortRecorded(
        uint256 indexed projectId,
        address indexed manager,
        uint256 jhdAmount,
        uint8 actionType,
        bytes32 proofHash
    );

    /// @dev Emitted when accumulated effort tokens are burned (e.g. on misconduct).
    /// @param projectId The project the effort was attributed to.
    /// @param manager   The manager whose tokens were burned.
    /// @param totalJHD  Total JHD tokens burned.
    /// @param reason    Human-readable reason for the burn.
    event EffortBurned(
        uint256 indexed projectId,
        address indexed manager,
        uint256 totalJHD,
        string reason
    );

    /// @dev Emitted after an efficiency score is computed for a manager.
    /// @param projectId       The project evaluated.
    /// @param manager         The manager evaluated.
    /// @param totalJHD        Total JHD tokens earned during the project.
    /// @param profitUSD       Profit denominated in USD.
    /// @param efficiencyScore Computed efficiency metric (higher is better).
    event EfficiencyCalculated(
        uint256 indexed projectId,
        address indexed manager,
        uint256 totalJHD,
        uint256 profitUSD,
        uint256 efficiencyScore
    );
}
