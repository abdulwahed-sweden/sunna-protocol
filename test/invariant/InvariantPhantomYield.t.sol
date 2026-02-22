// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/FeeController.sol";
import "../../src/core/SolvencyGuard.sol";

contract PhantomYieldHandler is Test {
    FeeController public controller;
    SolvencyGuard public solvencyGuard;
    uint256 public totalFeesOnLoss;

    constructor(FeeController _controller, SolvencyGuard _solvencyGuard) {
        controller = _controller;
        solvencyGuard = _solvencyGuard;
    }

    function calculateFeeWithLoss(uint256 profit, uint256 loss) external {
        profit = bound(profit, 0, 1e24);
        loss = bound(loss, 1, 1e24); // Always has loss

        // Create a deficit: set liabilities higher than assets
        solvencyGuard.setLiabilities(loss);

        uint256 fee = controller.calculateFee(profit);
        totalFeesOnLoss += fee;
    }
}

contract InvariantPhantomYieldTest is Test {
    SolvencyGuard public solvencyGuard;
    FeeController public controller;
    PhantomYieldHandler public handler;

    function setUp() public {
        solvencyGuard = new SolvencyGuard();
        controller = new FeeController(address(solvencyGuard), 500);

        handler = new PhantomYieldHandler(controller, solvencyGuard);

        // Authorize the handler as an engine so it can call setLiabilities
        solvencyGuard.authorizeEngine(address(handler));

        targetContract(address(handler));
    }

    /// @notice PY-1: Fee must be 0 when any loss exists
    function invariant_noPhantomYield() public view {
        assertEq(handler.totalFeesOnLoss(), 0, "PY-1 VIOLATED: fees generated during loss");
    }
}
