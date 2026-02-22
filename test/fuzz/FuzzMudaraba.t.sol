// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/mudaraba/MudarabaEngine.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock USDT", "mUSDT") {}
    function mint(address to, uint256 a) external { _mint(to, a); }
}

/// @title FuzzMudaraba — Random Profit/Loss Scenarios
/// @author Abdulwahed Mansour
contract FuzzMudarabaTest is Test {
    MudarabaEngine public engine;
    MockToken public token;
    address public funder = address(0x1);
    address public manager = address(0x2);

    function setUp() public {
        token = new MockToken();
        engine = new MudarabaEngine(address(token));
    }

    /// @notice Fuzz: token conservation — no tokens created or destroyed
    function testFuzz_tokenConservation(uint256 capital, uint256 finalBalance) public {
        capital = bound(capital, 1e6, 1e24);
        finalBalance = bound(finalBalance, 0, 2 * capital);

        // Fund the funder
        token.mint(funder, capital);
        vm.startPrank(funder);
        token.approve(address(engine), capital);
        uint256 pid = engine.createProject(manager, capital, 6000, 4000);
        vm.stopPrank();

        // Engine needs finalBalance tokens for settlement.
        // It already has `capital` from createProject.
        // For profit case (finalBalance > capital), mint the extra directly to engine.
        if (finalBalance > capital) {
            token.mint(address(engine), finalBalance - capital);
        }

        vm.prank(manager);
        engine.settle(pid, finalBalance);

        // Total tokens minted = capital + max(0, finalBalance - capital) = max(capital, finalBalance)
        uint256 totalMinted = capital + (finalBalance > capital ? finalBalance - capital : 0);
        uint256 totalHeld = token.balanceOf(funder) + token.balanceOf(manager) + token.balanceOf(address(engine));
        assertEq(totalHeld, totalMinted, "Token conservation violated");
    }

    /// @notice Fuzz: on loss, manager always gets zero
    function testFuzz_onLoss_managerGetsZero(uint256 capital, uint256 finalBalance) public {
        capital = bound(capital, 1e6, 1e24);
        finalBalance = bound(finalBalance, 0, capital); // loss case: finalBalance <= capital

        token.mint(funder, capital);
        vm.startPrank(funder);
        token.approve(address(engine), capital);
        uint256 pid = engine.createProject(manager, capital, 6000, 4000);
        vm.stopPrank();

        // Engine already has `capital` >= finalBalance, no extra mint needed
        vm.prank(manager);
        engine.settle(pid, finalBalance);

        // Manager never had tokens and gets 0 from loss settlement
        uint256 managerAfter = token.balanceOf(manager);
        assertEq(managerAfter, 0, "Manager should get zero on loss");
    }

    /// @notice Fuzz: on profit, funder gets at least their capital back
    function testFuzz_onProfit_funderGetsCapitalBack(uint256 capital, uint256 extraProfit) public {
        capital = bound(capital, 1e6, 1e24);
        extraProfit = bound(extraProfit, 1, capital);
        uint256 finalBalance = capital + extraProfit;

        token.mint(funder, capital);
        vm.startPrank(funder);
        token.approve(address(engine), capital);
        uint256 pid = engine.createProject(manager, capital, 6000, 4000);
        vm.stopPrank();

        // Mint extra profit tokens directly to engine for settlement
        token.mint(address(engine), extraProfit);

        vm.prank(manager);
        engine.settle(pid, finalBalance);

        uint256 funderBalance = token.balanceOf(funder);
        assertGe(funderBalance, capital, "Funder must get at least capital back on profit");
    }
}
