// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/FeeController.sol";

contract PhantomYieldHandler is Test {
    FeeController public controller;
    uint256 public totalFeesOnLoss;
    
    constructor(FeeController _controller) {
        controller = _controller;
    }
    
    function calculateFeeWithLoss(uint256 profit, uint256 loss) external {
        profit = bound(profit, 0, 1e24);
        loss = bound(loss, 1, 1e24); // Always has loss
        uint256 fee = controller.calculateFee(profit, loss);
        totalFeesOnLoss += fee;
    }
}

contract InvariantPhantomYieldTest is Test {
    FeeController public controller;
    PhantomYieldHandler public handler;
    
    function setUp() public {
        controller = new FeeController(address(1), address(this));
        handler = new PhantomYieldHandler(controller);
        
        targetContract(address(handler));
    }
    
    /// @notice PY-1: Fee must be 0 when any loss exists
    function invariant_noPhantomYield() public view {
        assertEq(handler.totalFeesOnLoss(), 0, "PY-1 VIOLATED: fees generated during loss");
    }
}
