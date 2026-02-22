// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ConstitutionalGuard} from "../../src/core/ConstitutionalGuard.sol";
import {SolvencyGuard} from "../../src/core/SolvencyGuard.sol";

contract ConstitutionalGuardTest is Test {
    ConstitutionalGuard public guard;
    SolvencyGuard public solvencyGuard;

    function setUp() public {
        solvencyGuard = new SolvencyGuard();
        guard = new ConstitutionalGuard(address(solvencyGuard));
    }

    // ── All six invariants are protected from genesis ──────────────

    function test_allInvariantsProtected() public view {
        assertTrue(guard.isProtected(guard.SE_1()));
        assertTrue(guard.isProtected(guard.PY_1()));
        assertTrue(guard.isProtected(guard.SD_1()));
        assertTrue(guard.isProtected(guard.CLA_1()));
        assertTrue(guard.isProtected(guard.CHC_1()));
        assertTrue(guard.isProtected(guard.DFB_1()));
    }

    // ── enforceConstitution does not revert for protected invariants ─

    function test_enforceConstitution_succeeds() public view {
        // Should not revert for any protected invariant
        guard.enforceConstitution(guard.SE_1());
        guard.enforceConstitution(guard.PY_1());
    }

    // ── attemptOverride reverts for protected invariants ────────────

    function test_attemptOverride_reverts() public {
        bytes32 se1 = guard.SE_1();
        vm.expectRevert(
            abi.encodeWithSelector(
                ConstitutionalGuard.ConstitutionalOverrideAttempt.selector,
                se1
            )
        );
        guard.attemptOverride(se1);
    }

    // ── attemptOverride does NOT revert for unprotected ids ─────────

    function test_attemptOverride_unprotected_passes() public view {
        bytes32 unknown = keccak256("UNKNOWN_INVARIANT");
        // Should not revert — the invariant is not protected
        guard.attemptOverride(unknown);
    }

    // ── isProtected returns false for unknown invariants ─────────────

    function test_isProtected_false_for_unknown() public view {
        bytes32 unknown = keccak256("NONEXISTENT");
        assertFalse(guard.isProtected(unknown));
    }

    // ── fullHealthCheck ─────────────────────────────────────────────

    function test_fullHealthCheck() public view {
        (bool solvent, bool allProtected) = guard.fullHealthCheck();
        assertTrue(solvent, "fresh SolvencyGuard should be solvent");
        assertTrue(allProtected, "all six invariants should be protected");
    }
}
