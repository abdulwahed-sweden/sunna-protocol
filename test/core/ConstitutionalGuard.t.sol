// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ConstitutionalGuard} from "../../src/core/ConstitutionalGuard.sol";

contract ConstitutionalGuardTest is Test {
    ConstitutionalGuard public guard;
    bytes32 public constant TEST_HASH = keccak256("SE-1: assets >= liabilities");

    function setUp() public {
        // deployer (this contract) is guardian
        guard = new ConstitutionalGuard(address(this));
    }

    function test_registerInvariant() public {
        guard.registerInvariant(TEST_HASH);
        assertTrue(guard.isRegistered(TEST_HASH));
    }

    function test_verifyInvariant_succeeds() public {
        guard.registerInvariant(TEST_HASH);
        // Should not revert
        guard.verifyInvariant(TEST_HASH);
    }

    function test_verifyInvariant_reverts() public {
        bytes32 unregisteredHash = keccak256("UNKNOWN_INVARIANT");
        vm.expectRevert(ConstitutionalGuard.InvariantNotRegistered.selector);
        guard.verifyInvariant(unregisteredHash);
    }

    function test_onlyGuardian_reverts() public {
        address randomUser = address(0xBEEF);
        vm.prank(randomUser);
        vm.expectRevert(ConstitutionalGuard.UnauthorizedGuardian.selector);
        guard.registerInvariant(TEST_HASH);
    }
}
