// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SunnaMath} from "../libraries/SunnaMath.sol";

/// @title SunnaShield — Protocol Adapter Layer
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice ERC-4626 wrapper that forces Sunna Protocol invariants onto existing
///         DeFi protocols — without their cooperation or code changes.
///         When capital is repaid with profit, fees are extracted.
///         When a loss is reported, ZERO fees are minted. By construction.
/// @dev The shield sits between depositors and underlying protocols (Aave,
///      Morpho, etc.), intercepting all value flows and applying invariants.
///      This is the retroactive fix for the ADS vulnerability class.
/// @custom:security-contact abdulwahed.mansour@protonmail.com
/// @custom:invariant ΔTreasury ≡ 0 IF ΔLoss > 0 (PY-1 via adapter).
contract SunnaShield is ERC4626, ReentrancyGuard {
    // ═══════════════════════════════════════════════════════════════
    //  Sunna Protocol — Sunna Shield (Adapter Layer)
    //  Authored by Abdulwahed Mansour / Sweden — February 2026
    //
    //  The Shield is the bridge between the broken world and the
    //  correct one. Existing DeFi protocols (Aave, Morpho, Curve)
    //  extract fees from phantom yield. They cannot fix themselves
    //  because their fee logic is embedded in their core contracts.
    //
    //  The Shield wraps these protocols in a protective layer that
    //  applies the Sunna invariants from outside. The underlying
    //  protocol doesn't need to change. The Shield forces compliance.
    //
    //  This is the practical answer to the $98.6M ADS vulnerability:
    //  you don't need to fix every protocol individually. You wrap
    //  them in a Shield that makes the fix universal.
    //
    //  Abdulwahed Mansour / Sweden — Invariant Labs
    //  Origin: ADS Discovery across Aave V4, Morpho Blue, Curve
    // ═══════════════════════════════════════════════════════════════

    using SafeERC20 for IERC20;
    using SunnaMath for uint256;

    // ──────────────────────────────────────
    // Errors
    // ──────────────────────────────────────

    error OnlyEngine();
    error ZeroAddress();
    error LossExceedsInvested(uint256 reported, uint256 invested);

    // ──────────────────────────────────────
    // Events
    // ──────────────────────────────────────

    event ProfitRealized(uint256 principal, uint256 profit, uint256 feeAmount);
    event LossReported(uint256 lossAmount, uint256 remainingInvested);
    event FeeSharesMinted(address indexed to, uint256 shares);

    // ──────────────────────────────────────
    // State
    // ──────────────────────────────────────

    address public immutable engine;

    /// @notice Total assets currently invested in underlying protocols.
    uint256 public investedAssets;

    /// @notice Management fee in basis points.
    uint16 public immutable feeBps;

    /// @notice Cumulative realized profit through this shield.
    uint256 public totalRealizedProfit;

    /// @notice Cumulative losses reported through this shield.
    uint256 public totalReportedLoss;

    // ──────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────

    /// @param _asset The underlying asset (stablecoin).
    /// @param _name Vault share token name.
    /// @param _symbol Vault share token symbol.
    /// @param _engine The authorized engine contract.
    /// @param _feeBps Management fee in basis points.
    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _engine,
        uint16 _feeBps
    ) ERC4626(_asset) ERC20(_name, _symbol) {
        if (_engine == address(0)) revert ZeroAddress();
        engine = _engine;
        feeBps = _feeBps;
    }

    // ──────────────────────────────────────
    // Core Shield Operations
    // ──────────────────────────────────────

    /// @notice Repay principal + profit. Fees extracted ONLY on realized profit.
    /// @dev This is where the Shield enforces PY-1 for external protocols.
    ///      The fee calculation uses multiply-before-divide via SunnaMath.
    /// @param principal The original capital being returned.
    /// @param profit The realized profit above principal.
    function repay(uint256 principal, uint256 profit) external nonReentrant {
        if (msg.sender != engine) revert OnlyEngine();

        investedAssets -= principal;
        totalRealizedProfit += profit;

        // Transfer the full amount from engine to shield
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), principal + profit);

        // Fees ONLY on realized profit — NEVER on principal, NEVER on loss
        uint256 feeAmount = 0;
        if (profit > 0) {
            feeAmount = profit.bpsOf(feeBps);
            if (feeAmount > 0) {
                uint256 feeShares = convertToShares(feeAmount);
                if (feeShares > 0) {
                    _mint(engine, feeShares);
                    emit FeeSharesMinted(engine, feeShares);
                }
            }
        }

        emit ProfitRealized(principal, profit, feeAmount);
    }

    /// @notice Report a loss — NO fee calculation, NO fee minting.
    /// @dev This is the constitutional invariant in adapter form:
    ///      ΔTreasury ≡ 0 IF ΔLoss > 0.
    ///      The ABSENCE of fee logic here is the most important
    ///      property of this function.
    /// @param lossAmount The amount of capital lost.
    function reportLoss(uint256 lossAmount) external nonReentrant {
        if (msg.sender != engine) revert OnlyEngine();
        if (lossAmount > investedAssets) {
            revert LossExceedsInvested(lossAmount, investedAssets);
        }

        investedAssets -= lossAmount;
        totalReportedLoss += lossAmount;

        // ════════════════════════════════════════════════════════
        // NO FEE CALCULATION. NO FEE MINTING. BY DESIGN.
        //
        // This empty space is the fix for a $98.6M vulnerability
        // class. Every DeFi lending protocol that calculates fees
        // during loss conditions has code where this space is.
        // We have nothing. That is the point.
        //
        // Abdulwahed Mansour / Sweden — this absence of code
        // is the invention. The Shield proves that doing nothing
        // at the right moment is the correct financial behavior.
        // ════════════════════════════════════════════════════════

        emit LossReported(lossAmount, investedAssets);
    }

    /// @notice Record capital deployment to underlying protocol.
    /// @param amount The amount being deployed.
    function recordInvestment(uint256 amount) external {
        if (msg.sender != engine) revert OnlyEngine();
        investedAssets += amount;
    }

    // ──────────────────────────────────────
    // View Functions
    // ──────────────────────────────────────

    /// @notice Get the shield's current state.
    /// @return _investedAssets Current invested amount.
    /// @return _totalProfit Cumulative profit.
    /// @return _totalLoss Cumulative loss.
    /// @return _netPerformance Net performance (profit - loss).
    function shieldStatus() external view returns (
        uint256 _investedAssets,
        uint256 _totalProfit,
        uint256 _totalLoss,
        int256 _netPerformance
    ) {
        _investedAssets = investedAssets;
        _totalProfit = totalRealizedProfit;
        _totalLoss = totalReportedLoss;
        _netPerformance = int256(totalRealizedProfit) - int256(totalReportedLoss);
    }
}
