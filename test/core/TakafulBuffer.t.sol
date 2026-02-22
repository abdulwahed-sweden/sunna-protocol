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
        solvencyGuard = new SolvencyGuard();
        buffer = new TakafulBuffer(address(token), address(solvencyGuard));

        // Authorize this test contract as an engine on both guards
        solvencyGuard.authorizeEngine(address(this));
        buffer.authorizeEngine(address(this));

        // Mint tokens to this contract and approve buffer
        token.mint(address(this), 1_000_000);
        token.approve(address(buffer), type(uint256).max);

        // Make system solvent: assets > liabilities
        solvencyGuard.increaseAssets(10_000);
    }

    function test_bufferFees() public {
        buffer.bufferFees(100);
        assertEq(buffer.totalBuffered(), 100);
    }

    function test_releaseFees() public {
        buffer.bufferFees(100);

        // Release fees — system is solvent
        buffer.releaseFees(recipient, 100);

        assertEq(token.balanceOf(recipient), 100);
        assertEq(buffer.totalBuffered(), 0);
    }

    function test_releaseFees_revertsWhenInsolvent() public {
        buffer.bufferFees(100);

        // Make the system insolvent: liabilities > assets
        solvencyGuard.setLiabilities(20_000);

        vm.expectRevert(TakafulBuffer.ProtocolInsolvent.selector);
        buffer.releaseFees(recipient, 100);
    }

    function test_useForRecovery() public {
        buffer.bufferFees(100);
        assertEq(buffer.totalBuffered(), 100);

        buffer.useForRecovery(50);
        assertEq(buffer.totalBuffered(), 50);
    }

    function test_onlyEngine_reverts() public {
        address randomUser = address(0xBEEF);
        vm.prank(randomUser);
        vm.expectRevert(TakafulBuffer.OnlyEngine.selector);
        buffer.bufferFees(100);
    }
}
