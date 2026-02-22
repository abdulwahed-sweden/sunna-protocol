// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {HELALToken} from "../../src/governance/HELALToken.sol";

contract HELALTokenTest is Test {
    HELALToken public helal;

    address public user = makeAddr("user");

    function setUp() public {
        // This test contract acts as governance
        helal = new HELALToken(address(this));
    }

    // ─── initial supply ────────────────────────────────────────

    function test_initialSupply() public view {
        uint256 expected = 10_000_000 * 1e18;
        assertEq(helal.totalSupply(), expected, "total supply should be 10M");
        assertEq(helal.balanceOf(address(this)), expected, "governance balance should be 10M");
    }

    // ─── mint ──────────────────────────────────────────────────

    function test_mint() public {
        uint256 mintAmount = 1_000_000 * 1e18;

        helal.mint(user, mintAmount);

        assertEq(helal.balanceOf(user), mintAmount, "user balance should equal minted amount");
        assertEq(helal.totalSupply(), 10_000_000 * 1e18 + mintAmount, "total supply should increase");
    }

    // ─── mint exceeds max supply — reverts ─────────────────────

    function test_mint_exceedsMaxSupply_reverts() public {
        uint256 mintAmount = 91_000_000 * 1e18; // 10M initial + 91M = 101M > 100M max

        vm.expectRevert(HELALToken.MaxSupplyExceeded.selector);
        helal.mint(user, mintAmount);
    }

    // ─── burn ──────────────────────────────────────────────────

    function test_burn() public {
        uint256 transferAmount = 5000e18;
        uint256 burnAmount = 2000e18;

        // Transfer tokens to user
        helal.transfer(user, transferAmount);
        assertEq(helal.balanceOf(user), transferAmount);

        // User burns some tokens
        vm.prank(user);
        helal.burn(burnAmount);

        assertEq(helal.balanceOf(user), transferAmount - burnAmount, "user balance should decrease by burn amount");
        assertEq(helal.totalSupply(), 10_000_000 * 1e18 - burnAmount, "total supply should decrease by burn amount");
    }

    // ─── onlyGovernance — mint reverts for non-governance ──────

    function test_onlyGovernance_mint_reverts() public {
        vm.prank(makeAddr("attacker"));
        vm.expectRevert(HELALToken.UnauthorizedGovernance.selector);
        helal.mint(user, 1000e18);
    }

    // ─── name and symbol ───────────────────────────────────────

    function test_name_and_symbol() public view {
        assertEq(helal.name(), "HELAL Token", "name mismatch");
        assertEq(helal.symbol(), "HELAL", "symbol mismatch");
    }
}
