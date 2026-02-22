// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title FeeController — PY-1: No Phantom Yield
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Calculates protocol fees only on real profit; returns zero when any loss exists
/// @dev Enforces the PY-1 invariant: fees are never charged on unrealized or phantom yield
contract FeeController {

    error PhantomYieldDetected();
    error ExcessiveFee();
    error UnauthorizedCaller();

    event FeeCalculated(uint256 profit, uint256 loss, uint256 fee);
    event FeeBpsUpdated(uint16 oldBps, uint16 newBps);

    address public immutable solvencyGuard;
    address public immutable admin;
    uint16 public feeBps = 500; // 5% default

    modifier onlyAdmin() {
        if (msg.sender != admin) revert UnauthorizedCaller();
        _;
    }

    constructor(address _solvencyGuard, address _admin) {
        solvencyGuard = _solvencyGuard;
        admin = _admin;
    }

    /// @notice Calculate fee on profit — returns 0 if any loss exists (PY-1)
    /// @param profit The realized profit amount
    /// @param loss The realized loss amount
    /// @return fee The calculated fee (0 if loss > 0)
    function calculateFee(uint256 profit, uint256 loss) external view returns (uint256 fee) {
        if (loss > 0) return 0;
        fee = (profit * feeBps) / 10_000;
    }

    /// @notice Update the fee basis points — only admin, max 2000 (20%)
    /// @param _feeBps The new fee in basis points
    function setFeeBps(uint16 _feeBps) external onlyAdmin {
        if (_feeBps > 2000) revert ExcessiveFee();
        uint16 oldBps = feeBps;
        feeBps = _feeBps;
        emit FeeBpsUpdated(oldBps, _feeBps);
    }
}
