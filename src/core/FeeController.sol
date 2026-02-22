// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SolvencyGuard} from "./SolvencyGuard.sol";
import {SunnaMath} from "../libraries/SunnaMath.sol";

/// @title FeeController — Phantom Yield Prevention (PY-1)
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Enforces PY-1: ΔTreasury ≡ 0 IF ΔLoss > 0.
///         Fees are calculated ONLY on realized profit, NEVER on unrealized
///         gains or during periods of active deficit.
/// @custom:security-contact abdulwahed.mansour@protonmail.com
/// @custom:invariant PY-1: No fee extraction when losses exist.
contract FeeController {
    // ═══════════════════════════════════════════════════════════════
    //  Sunna Protocol — Fee Controller
    //  Authored by Abdulwahed Mansour / Sweden — February 2026
    //
    //  The FeeController is the mathematical enforcement of a
    //  simple ethical principle: you cannot profit from a system
    //  that is losing other people's money.
    //
    //  Traditional DeFi calculates fees like this:
    //      fee = accruedInterest * feeRate
    //
    //  This is wrong. Accrued interest may never be collected.
    //  The borrower may default. The oracle may be stale. The
    //  interest is phantom — it exists on paper but not in reality.
    //
    //  Sunna Protocol calculates fees like this:
    //      IF protocol.isSolvent():
    //          fee = realizedProfit * feeRate
    //      ELSE:
    //          fee = 0  (constitutional invariant)
    //
    //  Abdulwahed Mansour / Sweden — Invariant Labs
    // ═══════════════════════════════════════════════════════════════

    using SunnaMath for uint256;

    // ──────────────────────────────────────
    // Errors
    // ──────────────────────────────────────

    error OnlyEngine();
    error ZeroAddress();
    error FeeBpsTooHigh(uint16 provided, uint16 maximum);
    error FeeExtractionBlocked(uint256 deficit);

    // ──────────────────────────────────────
    // Events
    // ──────────────────────────────────────

    event FeeCalculated(uint256 profit, uint256 feeAmount, uint16 feeBps);
    event FeeBlocked(uint256 attemptedProfit, uint256 currentDeficit);
    event FeeBpsUpdated(uint16 previousBps, uint16 newBps);

    // ──────────────────────────────────────
    // Constants
    // ──────────────────────────────────────

    /// @notice Maximum allowable fee rate: 20% (2000 bps).
    uint16 public constant MAX_FEE_BPS = 2000;

    // ──────────────────────────────────────
    // State
    // ──────────────────────────────────────

    SolvencyGuard public immutable solvencyGuard;
    address public immutable admin;

    /// @notice Management fee in basis points (e.g., 500 = 5%).
    uint16 public feeBps;

    /// @notice Cumulative fees that have been legitimately calculated.
    uint256 public totalFeesCalculated;

    /// @notice Cumulative fee calculations that were blocked due to deficit.
    uint256 public totalFeesBlocked;

    // ──────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────

    /// @param _solvencyGuard Address of the SolvencyGuard contract.
    /// @param _feeBps Initial fee rate in basis points.
    constructor(address _solvencyGuard, uint16 _feeBps) {
        if (_solvencyGuard == address(0)) revert ZeroAddress();
        if (_feeBps > MAX_FEE_BPS) revert FeeBpsTooHigh(_feeBps, MAX_FEE_BPS);

        solvencyGuard = SolvencyGuard(_solvencyGuard);
        admin = msg.sender;
        feeBps = _feeBps;
    }

    // ──────────────────────────────────────
    // Core Fee Logic
    // ──────────────────────────────────────

    /// @notice Calculate fee on realized profit — ONLY if the protocol is solvent.
    /// @dev This is the PY-1 invariant in executable form.
    ///      If deficit > 0, fee is ALWAYS zero. No exceptions. No overrides.
    /// @param realizedProfit The actual, collected, verified profit amount.
    /// @return feeAmount The fee to extract (zero if deficit exists).
    function calculateFee(uint256 realizedProfit) external returns (uint256 feeAmount) {
        uint256 deficit = solvencyGuard.currentDeficit();

        if (deficit > 0) {
            // PY-1 ENFORCEMENT: No fee during deficit. Period.
            totalFeesBlocked += realizedProfit.bpsOf(feeBps);
            emit FeeBlocked(realizedProfit, deficit);
            return 0;
        }

        // Protocol is solvent — fee is legitimate
        feeAmount = realizedProfit.bpsOf(feeBps);
        totalFeesCalculated += feeAmount;

        emit FeeCalculated(realizedProfit, feeAmount, feeBps);
    }

    /// @notice Preview fee calculation without state changes.
    /// @param realizedProfit The profit amount to calculate fee on.
    /// @return feeAmount The fee that would be charged (zero if deficit).
    /// @return blocked Whether the fee would be blocked.
    function previewFee(uint256 realizedProfit) external view returns (uint256 feeAmount, bool blocked) {
        uint256 deficit = solvencyGuard.currentDeficit();

        if (deficit > 0) {
            return (0, true);
        }

        feeAmount = realizedProfit.bpsOf(feeBps);
        blocked = false;
    }

    // ──────────────────────────────────────
    // Admin
    // ──────────────────────────────────────

    /// @notice Update the fee rate.
    /// @param newFeeBps New fee rate in basis points.
    function setFeeBps(uint16 newFeeBps) external {
        if (msg.sender != admin) revert OnlyEngine();
        if (newFeeBps > MAX_FEE_BPS) revert FeeBpsTooHigh(newFeeBps, MAX_FEE_BPS);

        uint16 previous = feeBps;
        feeBps = newFeeBps;
        emit FeeBpsUpdated(previous, newFeeBps);
    }
}
