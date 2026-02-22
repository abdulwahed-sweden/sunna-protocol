// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/SolvencyGuard.sol";

contract SolvencyHandler is Test {
    SolvencyGuard public guard;
    
    constructor(SolvencyGuard _guard) {
        guard = _guard;
    }
    
    function updateAssets(uint256 amount) external {
        amount = bound(amount, 0, 1e24);
        guard.updateAssets(amount);
    }
    
    function updateLiabilities(uint256 amount) external {
        amount = bound(amount, 0, guard.totalAssets());
        guard.updateLiabilities(amount);
    }
    
    function reportLoss(uint256 amount) external {
        uint256 maxLoss = guard.totalAssets();
        if (maxLoss == 0) return;
        amount = bound(amount, 0, maxLoss);
        guard.reportLoss(amount);
    }
}

contract InvariantSolvencyTest is Test {
    SolvencyGuard public guard;
    SolvencyHandler public handler;
    
    function setUp() public {
        guard = new SolvencyGuard(address(this));
        handler = new SolvencyHandler(guard);
        guard.updateAssets(1000e18);
        
        targetContract(address(handler));
    }
    
    /// @notice SE-1: Assets must always >= Liabilities
    function invariant_solvencyMaintained() public view {
        assertTrue(guard.totalAssets() >= guard.totalLiabilities(), "SE-1 VIOLATED: assets < liabilities");
    }
}
