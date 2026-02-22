// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ShariaGuard} from "../../src/core/ShariaGuard.sol";

contract ShariaGuardTest is Test {
    ShariaGuard public guard;

    function setUp() public {
        // deployer (this contract) is admin
        guard = new ShariaGuard();
    }

    function test_whitelistAsset() public {
        address asset = address(0xABCD);
        guard.whitelistAsset(asset, "Test asset");
        assertTrue(guard.isHalal(asset));
    }

    function test_delistAsset() public {
        address asset = address(0xABCD);
        guard.whitelistAsset(asset, "Test asset");
        assertTrue(guard.isHalal(asset));

        guard.delistAsset(asset, "No longer halal");
        assertFalse(guard.isHalal(asset));
    }

    function test_onlyAdmin_whitelistAsset_reverts() public {
        address randomUser = address(0xBEEF);
        vm.prank(randomUser);
        vm.expectRevert(ShariaGuard.OnlyAdmin.selector);
        guard.whitelistAsset(address(0xABCD), "Test asset");
    }

    function test_isHalal_defaultFalse() public view {
        address randomAsset = address(0xDEAD);
        assertFalse(guard.isHalal(randomAsset));
    }
}
