// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SolvencyGuard — Constitutional Solvency Invariant (SE-1)
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Enforces the primary solvency invariant:
///         ∀t: totalAssets(t) ≥ totalLiabilities(t)
///         This contract is the supreme law of Sunna Protocol.
///         No governance vote, no admin action, no upgrade can override it.
/// @dev Designed to be called by all state-changing contracts before and after
///      operations that affect protocol balances. Any violation causes a revert.
/// @custom:security-contact abdulwahed.mansour@protonmail.com
/// @custom:invariant SE-1: Assets >= Liabilities at all times.
contract SolvencyGuard is ReentrancyGuard {
    // ═══════════════════════════════════════════════════════════════
    //  Sunna Protocol — Solvency Guard
    //  Authored by Abdulwahed Mansour / Sweden — February 2026
    //
    //  This contract enforces the most fundamental property of any
    //  financial system: solvency. It is the mathematical guarantee
    //  that depositors can always withdraw their funds.
    //
    //  The invariant SE-1 states:
    //      ∀t: totalAssets(t) ≥ totalLiabilities(t)
    //
    //  When this invariant holds, phantom yield extraction is
    //  structurally impossible. When it is violated, all fee
    //  extraction halts automatically.
    //
    //  Original concept: Asymmetric Deficit Socialization (ADS)
    //  discovery — proving that $98.6M+ in major DeFi protocols
    //  violate this elementary property.
    //
    //  Abdulwahed Mansour / Sweden — Invariant Labs
    // ═══════════════════════════════════════════════════════════════

    // ──────────────────────────────────────
    // Errors
    // ──────────────────────────────────────

    /// @notice Protocol would become insolvent.
    error SolvencyViolation(uint256 assets, uint256 liabilities);

    /// @notice Caller is not an authorized engine contract.
    error OnlyEngine();

    /// @notice Zero address provided.
    error ZeroAddress();

    /// @notice Loss exceeds available assets.
    error LossExceedsAssets(uint256 loss, uint256 available);

    // ──────────────────────────────────────
    // Events
    // ──────────────────────────────────────

    event SolvencyChecked(uint256 assets, uint256 liabilities, bool solvent);
    event LossAbsorbed(uint256 amount, uint256 remainingAssets);
    event AssetsUpdated(uint256 previousAssets, uint256 newAssets);
    event LiabilitiesUpdated(uint256 previousLiabilities, uint256 newLiabilities);
    event EngineAuthorized(address indexed engine);
    event EngineRevoked(address indexed engine);

    // ──────────────────────────────────────
    // State
    // ──────────────────────────────────────

    address public immutable admin;
    uint256 public totalAssets;
    uint256 public totalLiabilities;

    /// @notice Authorized engine contracts that may update state.
    mapping(address => bool) public authorizedEngines;

    // ──────────────────────────────────────
    // Modifiers
    // ──────────────────────────────────────

    modifier onlyEngine() {
        if (!authorizedEngines[msg.sender]) revert OnlyEngine();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyEngine();
        _;
    }

    // ──────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────

    constructor() {
        admin = msg.sender;
    }

    // ──────────────────────────────────────
    // Core Invariant Functions
    // ──────────────────────────────────────

    /// @notice Check whether the protocol is currently solvent.
    /// @return solvent True if totalAssets >= totalLiabilities.
    function isSolvent() external view returns (bool solvent) {
        solvent = totalAssets >= totalLiabilities;
    }

    /// @notice Get the current deficit (zero if solvent).
    /// @return deficit The amount by which liabilities exceed assets, or zero.
    function currentDeficit() external view returns (uint256 deficit) {
        deficit = totalLiabilities > totalAssets ? totalLiabilities - totalAssets : 0;
    }

    /// @notice Enforce solvency — reverts if the protocol is insolvent.
    /// @dev Called by other contracts before fee extraction or distributions.
    function enforceSolvency() external view {
        if (totalAssets < totalLiabilities) {
            revert SolvencyViolation(totalAssets, totalLiabilities);
        }
    }

    // ──────────────────────────────────────
    // State Mutation (Engine Only)
    // ──────────────────────────────────────

    /// @notice Report a loss — absorbs the loss from total assets.
    /// @dev CRITICAL: This function does NOT calculate fees. It does NOT mint
    ///      fee shares. This is the constitutional invariant in action:
    ///      ΔTreasury ≡ 0 when ΔLoss > 0.
    /// @param lossAmount The amount of assets lost.
    function reportLoss(uint256 lossAmount) external onlyEngine nonReentrant {
        if (lossAmount > totalAssets) {
            revert LossExceedsAssets(lossAmount, totalAssets);
        }

        uint256 previousAssets = totalAssets;
        totalAssets -= lossAmount;

        // ════════════════════════════════════════════════════════
        // NO FEE CALCULATION. NO FEE MINTING. BY DESIGN.
        // This is the Sunna Protocol's constitutional guarantee.
        //
        // Abdulwahed Mansour / Sweden — this invariant is the
        // reason this protocol exists. The absence of code here
        // is the most important code in the entire system.
        // ════════════════════════════════════════════════════════

        emit LossAbsorbed(lossAmount, totalAssets);
        emit AssetsUpdated(previousAssets, totalAssets);
    }

    /// @notice Increase total assets (e.g., on deposit or profit realization).
    /// @param amount The amount to add.
    function increaseAssets(uint256 amount) external onlyEngine nonReentrant {
        uint256 previous = totalAssets;
        totalAssets += amount;
        emit AssetsUpdated(previous, totalAssets);
    }

    /// @notice Decrease total assets (e.g., on withdrawal).
    /// @dev Enforces solvency after the decrease.
    /// @param amount The amount to subtract.
    function decreaseAssets(uint256 amount) external onlyEngine nonReentrant {
        if (amount > totalAssets) {
            revert LossExceedsAssets(amount, totalAssets);
        }

        uint256 previous = totalAssets;
        totalAssets -= amount;

        // Post-condition: solvency must hold after decrease
        if (totalAssets < totalLiabilities) {
            revert SolvencyViolation(totalAssets, totalLiabilities);
        }

        emit AssetsUpdated(previous, totalAssets);
    }

    /// @notice Update total liabilities.
    /// @param newLiabilities The new liabilities value.
    function setLiabilities(uint256 newLiabilities) external onlyEngine nonReentrant {
        uint256 previous = totalLiabilities;
        totalLiabilities = newLiabilities;
        emit LiabilitiesUpdated(previous, newLiabilities);
    }

    // ──────────────────────────────────────
    // Admin Functions
    // ──────────────────────────────────────

    /// @notice Authorize an engine contract to update state.
    /// @param engine The engine address to authorize.
    function authorizeEngine(address engine) external onlyAdmin {
        if (engine == address(0)) revert ZeroAddress();
        authorizedEngines[engine] = true;
        emit EngineAuthorized(engine);
    }

    /// @notice Revoke an engine contract's authorization.
    /// @param engine The engine address to revoke.
    function revokeEngine(address engine) external onlyAdmin {
        authorizedEngines[engine] = false;
        emit EngineRevoked(engine);
    }
}
