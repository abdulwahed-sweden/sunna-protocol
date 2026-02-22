// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/governance/HELALToken.sol";

/// @title HELALToken Tests — Governance Token Verification
/// @author Abdulwahed Mansour — Sunna Protocol
contract HELALTokenTest is Test {
    HELALToken token;
    address treasury = makeAddr("treasury");

    function setUp() public {
        token = new HELALToken(treasury);
    }

    function test_initialSupply() public view {
        assertEq(token.totalSupply(), 100_000_000e18);
        assertEq(token.balanceOf(treasury), 100_000_000e18);
    }

    function test_name() public view {
        assertEq(token.name(), "HELAL");
        assertEq(token.symbol(), "HELAL");
    }

    function test_transfer() public {
        address alice = makeAddr("alice");
        vm.prank(treasury);
        token.transfer(alice, 1000e18);
        assertEq(token.balanceOf(alice), 1000e18);
    }

    function test_revertsZeroTreasury() public {
        vm.expectRevert();
        new HELALToken(address(0));
    }
}
