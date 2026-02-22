// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SunnaShield — Adapter Layer
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Wraps existing DeFi protocols to enforce no-fee-on-loss invariant
contract SunnaShield is ERC4626, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error FeeOnLossViolation();
    error UnauthorizedEngine();

    event ProfitRealized(uint256 principal, uint256 profit, uint256 feeShares);
    event LossReported(uint256 lossAmount);

    address public immutable engine;
    uint256 public investedAssets;
    uint16 public managementFeeBps; // basis points (e.g., 500 = 5%)

    modifier onlyEngine() {
        if (msg.sender != engine) revert UnauthorizedEngine();
        _;
    }

    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _engine,
        uint16 _feeBps
    ) ERC4626(_asset) ERC20(_name, _symbol) {
        engine = _engine;
        managementFeeBps = _feeBps;
    }

    /// @notice Repay principal + profit — fees ONLY on realized profit
    function repay(uint256 principal, uint256 profit) external onlyEngine nonReentrant {
        investedAssets -= principal;
        IERC20(asset()).safeTransferFrom(engine, address(this), principal + profit);

        uint256 feeShares = 0;
        if (profit > 0) {
            feeShares = _mintFeeShares((profit * managementFeeBps) / 10_000);
        }
        // Fees ONLY on realized profit — NEVER on loss. By construction.
        emit ProfitRealized(principal, profit, feeShares);
    }

    /// @notice Report loss — NO fee calculation, NO fee minting
    /// @dev Constitutional invariant: ΔTreasury ≡ 0 IF loss > 0
    function reportLoss(uint256 lossAssets) external onlyEngine nonReentrant {
        require(lossAssets <= investedAssets, "SUNNA: loss > invested");
        investedAssets -= lossAssets;
        // NO FEE CALCULATION. NO FEE MINTING. BY DESIGN.
        emit LossReported(lossAssets);
    }

    /// @notice Track invested assets on deposit
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual override {
        super._deposit(caller, receiver, assets, shares);
        investedAssets += assets;
    }

    function _mintFeeShares(uint256 feeAmount) internal returns (uint256 shares) {
        shares = convertToShares(feeAmount);
        if (shares > 0) {
            _mint(engine, shares);
        }
    }
}
