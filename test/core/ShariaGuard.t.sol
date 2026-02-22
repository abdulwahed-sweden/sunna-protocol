// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ShariaGuard} from "../../src/core/ShariaGuard.sol";

contract ShariaGuardTest is Test {
    ShariaGuard public guard;

    function setUp() public {
        // deployer (this contract) is admin
        guard = new ShariaGuard(address(this));
    }

    function test_addToWhitelist() public {
        address protocol = address(0xABCD);
        guard.addToWhitelist(protocol);
        assertTrue(guard.isHalal(protocol));
    }

    function test_removeFromWhitelist() public {
        address protocol = address(0xABCD);
        guard.addToWhitelist(protocol);
        assertTrue(guard.isHalal(protocol));

        guard.removeFromWhitelist(protocol);
        assertFalse(guard.isHalal(protocol));
    }

    function test_onlyAdmin_addToWhitelist_reverts() public {
        address randomUser = address(0xBEEF);
        vm.prank(randomUser);
        vm.expectRevert(ShariaGuard.UnauthorizedCaller.selector);
        guard.addToWhitelist(address(0xABCD));
    }

    function test_isHalal_defaultFalse() public view {
        address randomProtocol = address(0xDEAD);
        assertFalse(guard.isHalal(randomProtocol));
    }
}
