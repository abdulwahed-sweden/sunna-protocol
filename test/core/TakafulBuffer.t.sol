// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SolvencyGuard} from "../../src/core/SolvencyGuard.sol";
import {TakafulBuffer} from "../../src/core/TakafulBuffer.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TakafulBufferTest is Test {
    MockERC20 public token;
    SolvencyGuard public solvencyGuard;
    TakafulBuffer public buffer;

    address public recipient = address(0xCAFE);

    function setUp() public {
        token = new MockERC20();
        solvencyGuard = new SolvencyGuard(address(this));
        buffer = new TakafulBuffer(
            address(solvencyGuard),
            address(token),
            address(this)
        );

        // Mint tokens to test contract and approve buffer to spend them
        token.mint(address(this), 1_000_000);
        token.approve(address(buffer), type(uint256).max);

        // Set solvency guard assets so system starts solvent
        solvencyGuard.updateAssets(10000);
    }

    function test_escrowFee() public {
        buffer.escrowFee(recipient, 100);
        assertEq(buffer.escrowedFees(recipient), 100);
    }

    function test_releaseFees() public {
        buffer.escrowFee(recipient, 100);

        // Release fees — system is solvent
        buffer.releaseFees(recipient);

        assertEq(token.balanceOf(recipient), 100);
        assertEq(buffer.escrowedFees(recipient), 0);
    }

    function test_releaseFees_revertsWhenInsolvent() public {
        buffer.escrowFee(recipient, 100);

        // Make the system insolvent: assets=0, liabilities=100
        solvencyGuard.updateAssets(0);
        solvencyGuard.updateLiabilities(100);

        vm.expectRevert(TakafulBuffer.InsolvencyDetected.selector);
        buffer.releaseFees(recipient);
    }

    function test_forfeitFees() public {
        buffer.escrowFee(recipient, 100);
        assertEq(buffer.escrowedFees(recipient), 100);

        buffer.forfeitFees(recipient);
        assertEq(buffer.escrowedFees(recipient), 0);
    }

    function test_onlyAdmin_reverts() public {
        address randomUser = address(0xBEEF);
        vm.prank(randomUser);
        vm.expectRevert(TakafulBuffer.UnauthorizedCaller.selector);
        buffer.escrowFee(recipient, 100);
    }
}
