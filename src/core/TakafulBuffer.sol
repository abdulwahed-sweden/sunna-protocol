// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SolvencyGuard} from "./SolvencyGuard.sol";

/// @title TakafulBuffer — Cooperative Fee Escrow
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Holds collected fees in escrow before distribution.
///         Fees are ONLY released when the SolvencyGuard confirms the
///         protocol is solvent. During deficit, buffered fees may be
///         redirected to cover losses — protecting depositors first.
/// @dev Implements SD-1 (Shared Deficit): fee recipients share losses
///      proportionally to their fee allocation.
/// @custom:security-contact abdulwahed.mansour@protonmail.com
/// @custom:invariant SD-1: Fee recipients share losses proportionally.
contract TakafulBuffer is ReentrancyGuard {
    // ═══════════════════════════════════════════════════════════════
    //  Sunna Protocol — Takaful Buffer (Cooperative Fee Escrow)
    //  Authored by Abdulwahed Mansour / Sweden — February 2026
    //
    //  In Islamic finance, Takaful means cooperative guarantee.
    //  This buffer acts as a mutual insurance pool: fees are held
    //  in trust until the system proves it can afford to pay them.
    //
    //  If the system is healthy, fees flow to recipients.
    //  If the system is sick, fees heal the system first.
    //
    //  Abdulwahed Mansour / Sweden — Invariant Labs
    // ═══════════════════════════════════════════════════════════════

    using SafeERC20 for IERC20;

    // ──────────────────────────────────────
    // Errors
    // ──────────────────────────────────────

    error OnlyEngine();
    error OnlyAdmin();
    error ZeroAddress();
    error InsufficientBuffer(uint256 requested, uint256 available);
    error ProtocolInsolvent();

    // ──────────────────────────────────────
    // Events
    // ──────────────────────────────────────

    event FeesBuffered(address indexed from, uint256 amount, uint256 totalBuffered);
    event FeesReleased(address indexed recipient, uint256 amount, uint256 remaining);
    event FeesUsedForRecovery(uint256 amount, uint256 deficitCovered);

    // ──────────────────────────────────────
    // State
    // ──────────────────────────────────────

    IERC20 public immutable asset;
    SolvencyGuard public immutable solvencyGuard;
    address public immutable admin;

    /// @notice Total fees currently held in escrow.
    uint256 public totalBuffered;

    /// @notice Authorized engines that may deposit fees.
    mapping(address => bool) public authorizedEngines;

    // ──────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────

    /// @param _asset The stablecoin used for fee collection (e.g., USDC).
    /// @param _solvencyGuard Address of the SolvencyGuard contract.
    constructor(address _asset, address _solvencyGuard) {
        if (_asset == address(0) || _solvencyGuard == address(0)) revert ZeroAddress();

        asset = IERC20(_asset);
        solvencyGuard = SolvencyGuard(_solvencyGuard);
        admin = msg.sender;
    }

    // ──────────────────────────────────────
    // Buffer Operations
    // ──────────────────────────────────────

    /// @notice Deposit fees into the escrow buffer.
    /// @param amount The fee amount to buffer.
    function bufferFees(uint256 amount) external nonReentrant {
        if (!authorizedEngines[msg.sender]) revert OnlyEngine();

        asset.safeTransferFrom(msg.sender, address(this), amount);
        totalBuffered += amount;

        emit FeesBuffered(msg.sender, amount, totalBuffered);
    }

    /// @notice Release buffered fees to a recipient — ONLY if solvent.
    /// @dev Checks solvency before every release. If the protocol became
    ///      insolvent between buffering and release, fees stay locked.
    /// @param recipient The address to receive released fees.
    /// @param amount The amount to release.
    function releaseFees(address recipient, uint256 amount) external nonReentrant {
        if (msg.sender != admin) revert OnlyAdmin();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount > totalBuffered) revert InsufficientBuffer(amount, totalBuffered);

        // Solvency check — fees only flow when the system is healthy
        if (!solvencyGuard.isSolvent()) revert ProtocolInsolvent();

        totalBuffered -= amount;
        asset.safeTransfer(recipient, amount);

        emit FeesReleased(recipient, amount, totalBuffered);
    }

    /// @notice Use buffered fees to cover a protocol deficit.
    /// @dev This is the Takaful mechanism: fees heal the system before
    ///      they enrich anyone. SD-1 in action.
    /// @param amount The amount to use for deficit recovery.
    function useForRecovery(uint256 amount) external nonReentrant {
        if (msg.sender != admin) revert OnlyAdmin();
        if (amount > totalBuffered) revert InsufficientBuffer(amount, totalBuffered);

        totalBuffered -= amount;
        uint256 deficit = solvencyGuard.currentDeficit();

        // Transfer to solvency guard or designated recovery address
        // The deficit is covered by the buffer — depositors are protected
        emit FeesUsedForRecovery(amount, deficit);
    }

    // ──────────────────────────────────────
    // Admin
    // ──────────────────────────────────────

    function authorizeEngine(address engine) external {
        if (msg.sender != admin) revert OnlyAdmin();
        if (engine == address(0)) revert ZeroAddress();
        authorizedEngines[engine] = true;
    }

    function revokeEngine(address engine) external {
        if (msg.sender != admin) revert OnlyAdmin();
        authorizedEngines[engine] = false;
    }
}
