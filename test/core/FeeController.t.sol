// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {FeeController} from "../../src/core/FeeController.sol";

contract FeeControllerTest is Test {
    FeeController public controller;

    function setUp() public {
        // Pass a dummy solvency guard address; admin is this contract
        address dummySolvencyGuard = address(0x1234);
        controller = new FeeController(dummySolvencyGuard, address(this));
    }

    function test_calculateFee_withProfit() public view {
        // profit=1000, loss=0, feeBps=500 => fee = 1000 * 500 / 10000 = 50
        uint256 fee = controller.calculateFee(1000, 0);
        assertEq(fee, 50);
    }

    function test_calculateFee_withLoss() public view {
        // Any loss > 0 => fee must be 0 (PY-1 invariant)
        uint256 fee = controller.calculateFee(1000, 500);
        assertEq(fee, 0);
    }

    function test_calculateFee_zeroProfit() public view {
        // profit=0, loss=0 => fee = 0 * 500 / 10000 = 0
        uint256 fee = controller.calculateFee(0, 0);
        assertEq(fee, 0);
    }

    function test_setFeeBps() public {
        controller.setFeeBps(1000);
        assertEq(controller.feeBps(), 1000);
    }

    function test_setFeeBps_exceedsMax_reverts() public {
        // Max is 2000 (20%), so 3000 should revert
        vm.expectRevert(FeeController.ExcessiveFee.selector);
        controller.setFeeBps(3000);
    }

    function test_onlyAdmin_setFeeBps_reverts() public {
        address randomUser = address(0xBEEF);
        vm.prank(randomUser);
        vm.expectRevert(FeeController.UnauthorizedCaller.selector);
        controller.setFeeBps(1000);
    }
}
