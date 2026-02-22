// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/mudaraba/SunnaLedger.sol";

contract JHDHandler is Test {
    SunnaLedger public ledger;
    address public manager = address(0xBEEF);
    uint256 public previousJHD;
    
    constructor(SunnaLedger _ledger) {
        ledger = _ledger;
    }
    
    function recordEffort(uint8 actionType) external {
        actionType = uint8(bound(actionType, 0, 4));
        ledger.recordEffort(0, manager, SunnaLedger.ActionType(actionType), keccak256(abi.encodePacked(block.timestamp)));
    }
}

contract InvariantJHDTest is Test {
    SunnaLedger public ledger;
    JHDHandler public handler;
    address public manager = address(0xBEEF);
    
    function setUp() public {
        ledger = new SunnaLedger();
        ledger.setAuthorizedRecorder(address(this), true);
        
        handler = new JHDHandler(ledger);
        ledger.setAuthorizedRecorder(address(handler), true);
        
        targetContract(address(handler));
    }
    
    /// @notice JHD: Manager's totalJHD must be monotonically non-decreasing
    function invariant_jhdMonotonicallyIncreasing() public view {
        (uint256 totalJHD,,,,) = ledger.getProjectEffort(0);
        assertTrue(totalJHD >= handler.previousJHD(), "JHD VIOLATED: totalJHD decreased");
    }
}
