// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SolvencyGuard — Constitutional Solvency Invariant
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Enforces SE-1: System assets must always cover liabilities
/// @dev This contract cannot be upgraded or bypassed by governance
contract SolvencyGuard {

    error SolvencyViolation(uint256 assets, uint256 liabilities);
    error UnauthorizedCaller();

    event SolvencyChecked(uint256 assets, uint256 liabilities, bool solvent);
    event LossReported(uint256 amount, uint256 remainingAssets);

    address public immutable engine;
    uint256 public totalAssets;
    uint256 public totalLiabilities;

    modifier onlyEngine() {
        if (msg.sender != engine) revert UnauthorizedCaller();
        _;
    }

    constructor(address _engine) {
        engine = _engine;
    }

    /// @notice Check solvency — MUST be called before any fee extraction
    /// @return solvent True if assets >= liabilities
    function checkSolvency() external view returns (bool solvent) {
        solvent = totalAssets >= totalLiabilities;
    }

    /// @notice Report a loss — NO fees are calculated, NO fees are minted
    /// @dev This is the constitutional invariant: ΔTreasury = 0 when loss > 0
    function reportLoss(uint256 lossAmount) external onlyEngine {
        require(lossAmount <= totalAssets, "SUNNA: loss exceeds assets");
        totalAssets -= lossAmount;
        // NO FEE CALCULATION. NO FEE MINTING. BY DESIGN.
        emit LossReported(lossAmount, totalAssets);
    }

    /// @notice Enforce solvency — reverts if violated
    function enforceSolvency() external view {
        if (totalAssets < totalLiabilities) {
            revert SolvencyViolation(totalAssets, totalLiabilities);
        }
    }

    /// @notice Update total assets — only callable by engine
    function updateAssets(uint256 _totalAssets) external onlyEngine {
        totalAssets = _totalAssets;
        emit SolvencyChecked(_totalAssets, totalLiabilities, _totalAssets >= totalLiabilities);
    }

    /// @notice Update total liabilities — only callable by engine
    function updateLiabilities(uint256 _totalLiabilities) external onlyEngine {
        totalLiabilities = _totalLiabilities;
        emit SolvencyChecked(totalAssets, _totalLiabilities, totalAssets >= _totalLiabilities);
    }
}
