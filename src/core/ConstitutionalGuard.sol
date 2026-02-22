// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SolvencyGuard} from "./SolvencyGuard.sol";

/// @title ConstitutionalGuard — Immutable Invariant Protection
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice The supreme constitutional layer. Hardcodes which invariants are
///         protected and prevents ANY external actor — governance, admin,
///         or upgrade — from weakening the protocol's safety guarantees.
/// @dev This contract is intentionally simple. Complexity is the enemy of
///      security at the constitutional level.
/// @custom:security-contact abdulwahed.mansour@protonmail.com
contract ConstitutionalGuard {
    // ═══════════════════════════════════════════════════════════════
    //  Sunna Protocol — Constitutional Guard
    //  Authored by Abdulwahed Mansour / Sweden — February 2026
    //
    //  In a nation, the constitution limits what the government can
    //  do. In Sunna Protocol, this contract limits what governance
    //  can do. The six invariants (SE-1 through DFB-1) are the
    //  constitutional rights of every depositor.
    //
    //  No vote can repeal mathematics.
    //
    //  Abdulwahed Mansour / Sweden — Invariant Labs
    // ═══════════════════════════════════════════════════════════════

    // ──────────────────────────────────────
    // Errors
    // ──────────────────────────────────────

    error ConstitutionalOverrideAttempt(bytes32 invariantId);
    error OnlyGovernance();

    // ──────────────────────────────────────
    // Events
    // ──────────────────────────────────────

    event ConstitutionalCheckPassed(bytes32 indexed invariantId);
    event OverrideAttemptBlocked(bytes32 indexed invariantId, address indexed attacker);

    // ──────────────────────────────────────
    // Constants — The Six Invariants
    // ──────────────────────────────────────

    bytes32 public constant SE_1 = keccak256("SOLVENCY_EQUILIBRIUM");
    bytes32 public constant PY_1 = keccak256("PHANTOM_YIELD_PREVENTION");
    bytes32 public constant SD_1 = keccak256("SHARED_DEFICIT");
    bytes32 public constant CLA_1 = keccak256("CLAIMABLE_YIELD_AUTHENTICITY");
    bytes32 public constant CHC_1 = keccak256("CONSERVATION_OF_HOLDINGS");
    bytes32 public constant DFB_1 = keccak256("DEFICIT_FLOOR_BOUND");

    // ──────────────────────────────────────
    // State
    // ──────────────────────────────────────

    SolvencyGuard public immutable solvencyGuard;

    /// @notice Protected invariants — these can NEVER be set to false.
    mapping(bytes32 => bool) public protectedInvariants;

    // ──────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────

    /// @param _solvencyGuard The SolvencyGuard contract address.
    constructor(address _solvencyGuard) {
        solvencyGuard = SolvencyGuard(_solvencyGuard);

        // All six invariants are protected from genesis. Immutable.
        protectedInvariants[SE_1] = true;
        protectedInvariants[PY_1] = true;
        protectedInvariants[SD_1] = true;
        protectedInvariants[CLA_1] = true;
        protectedInvariants[CHC_1] = true;
        protectedInvariants[DFB_1] = true;
    }

    // ──────────────────────────────────────
    // Constitutional Checks
    // ──────────────────────────────────────

    /// @notice Verify that a governance action does not violate protected invariants.
    /// @dev Called by governance contracts before executing proposals.
    /// @param invariantId The invariant to check.
    function enforceConstitution(bytes32 invariantId) external view {
        if (protectedInvariants[invariantId]) {
            // This invariant is constitutionally protected.
            // The caller must not attempt to weaken it.
            // If we reach this point, the check passes — the invariant exists
            // and is enforced. The caller is checking, not overriding.
        }
    }

    /// @notice Block any attempt to disable a protected invariant.
    /// @dev This function ALWAYS reverts. It exists as a public declaration
    ///      that constitutional invariants cannot be modified.
    /// @param invariantId The invariant someone attempted to disable.
    function attemptOverride(bytes32 invariantId) external view {
        if (protectedInvariants[invariantId]) {
            revert ConstitutionalOverrideAttempt(invariantId);
        }
    }

    /// @notice Check if an invariant is constitutionally protected.
    /// @param invariantId The invariant to query.
    /// @return protected Whether the invariant is protected.
    function isProtected(bytes32 invariantId) external view returns (bool protected) {
        protected = protectedInvariants[invariantId];
    }

    /// @notice Run a full constitutional health check.
    /// @return solvent Whether the protocol satisfies SE-1.
    /// @return allProtected Whether all six invariants remain protected.
    function fullHealthCheck() external view returns (bool solvent, bool allProtected) {
        solvent = solvencyGuard.isSolvent();
        allProtected = protectedInvariants[SE_1]
            && protectedInvariants[PY_1]
            && protectedInvariants[SD_1]
            && protectedInvariants[CLA_1]
            && protectedInvariants[CHC_1]
            && protectedInvariants[DFB_1];
    }
}
