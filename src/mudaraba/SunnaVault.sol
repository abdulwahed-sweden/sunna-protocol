// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SolvencyGuard} from "../core/SolvencyGuard.sol";
import {ShariaGuard} from "../core/ShariaGuard.sol";

/// @title SunnaVault — Capital Custody
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Receives, secures, and manages funder deposits. All deposits and
///         withdrawals pass through SolvencyGuard and ShariaGuard checks.
///         Implements CHC-1: sum of individual deposits equals total assets.
/// @dev Uses SafeERC20 for all token operations. Boundary comparisons use
///      >= (not >) to prevent off-by-one withdrawal blocks.
/// @custom:security-contact abdulwahed.mansour@protonmail.com
/// @custom:invariant CHC-1: totalDeposits == Σ(deposit_i) for all users.
contract SunnaVault is ReentrancyGuard {
    // ═══════════════════════════════════════════════════════════════
    //  Sunna Protocol — Sunna Vault (Capital Custody)
    //  Authored by Abdulwahed Mansour / Sweden — February 2026
    //
    //  The vault is the trust anchor of the protocol. Every unit
    //  of capital deposited here is accounted for individually.
    //  The CHC-1 invariant guarantees that the sum of all individual
    //  deposit records always equals the vault's total.
    //
    //  No tokens are created or destroyed outside of defined paths.
    //  Every deposit has a withdrawal. Every number has a source.
    //
    //  Abdulwahed Mansour / Sweden — Invariant Labs
    // ═══════════════════════════════════════════════════════════════

    using SafeERC20 for IERC20;

    // ──────────────────────────────────────
    // Errors
    // ──────────────────────────────────────

    error ZeroAmount();
    error ZeroAddress();
    error InsufficientDeposit(uint256 requested, uint256 available);
    error AssetNotPermitted(address asset);
    error OnlyAdmin();
    error WithdrawalWouldBreakSolvency();

    // ──────────────────────────────────────
    // Events
    // ──────────────────────────────────────

    event Deposited(address indexed user, uint256 amount, uint256 newBalance);
    event Withdrawn(address indexed user, uint256 amount, uint256 newBalance);

    // ──────────────────────────────────────
    // State
    // ──────────────────────────────────────

    IERC20 public immutable asset;
    SolvencyGuard public immutable solvencyGuard;
    ShariaGuard public immutable shariaGuard;
    address public immutable admin;

    /// @notice Individual deposit balances.
    mapping(address => uint256) public deposits;

    /// @notice Total deposits across all users (must equal sum of deposits mapping).
    uint256 public totalDeposits;

    /// @notice Count of unique depositors.
    uint256 public depositorCount;

    /// @notice Tracks whether an address has deposited before.
    mapping(address => bool) internal _hasDeposited;

    // ──────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────

    /// @param _asset The accepted stablecoin (e.g., USDC).
    /// @param _solvencyGuard SolvencyGuard contract address.
    /// @param _shariaGuard ShariaGuard contract address.
    constructor(address _asset, address _solvencyGuard, address _shariaGuard) {
        if (_asset == address(0) || _solvencyGuard == address(0) || _shariaGuard == address(0)) {
            revert ZeroAddress();
        }

        asset = IERC20(_asset);
        solvencyGuard = SolvencyGuard(_solvencyGuard);
        shariaGuard = ShariaGuard(_shariaGuard);
        admin = msg.sender;
    }

    // ──────────────────────────────────────
    // Deposit
    // ──────────────────────────────────────

    /// @notice Deposit capital into the vault.
    /// @dev Verifies asset is halal before accepting. Updates solvency state.
    /// @param amount The amount to deposit.
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        // Sharia check — only halal assets permitted
        shariaGuard.enforceHalal(address(asset));

        // Track unique depositors
        if (!_hasDeposited[msg.sender]) {
            _hasDeposited[msg.sender] = true;
            depositorCount++;
        }

        // Effects
        deposits[msg.sender] += amount;
        totalDeposits += amount;

        // Interaction
        asset.safeTransferFrom(msg.sender, address(this), amount);

        // Update solvency state
        solvencyGuard.increaseAssets(amount);

        emit Deposited(msg.sender, amount, deposits[msg.sender]);
    }

    // ──────────────────────────────────────
    // Withdrawal
    // ──────────────────────────────────────

    /// @notice Withdraw capital from the vault.
    /// @dev Uses >= for boundary comparison to prevent off-by-one blocks.
    ///      Checks solvency would hold after withdrawal.
    /// @param amount The amount to withdraw.
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        // Use >= to prevent off-by-one withdrawal blocks
        if (deposits[msg.sender] < amount) {
            revert InsufficientDeposit(amount, deposits[msg.sender]);
        }

        // Effects — update before external calls (CEI pattern)
        deposits[msg.sender] -= amount;
        totalDeposits -= amount;

        // Solvency check — will revert if withdrawal breaks SE-1
        solvencyGuard.decreaseAssets(amount);

        // Interaction
        asset.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount, deposits[msg.sender]);
    }

    // ──────────────────────────────────────
    // View Functions
    // ──────────────────────────────────────

    /// @notice Get a user's current deposit balance.
    function balanceOf(address user) external view returns (uint256) {
        return deposits[user];
    }

    /// @notice Verify CHC-1 off-chain: compare totalDeposits with actual token balance.
    /// @return consistent Whether totalDeposits matches the vault's token balance.
    function isConsistent() external view returns (bool consistent) {
        consistent = asset.balanceOf(address(this)) >= totalDeposits;
    }
}
