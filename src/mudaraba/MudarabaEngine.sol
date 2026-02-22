// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SunnaMath} from "../libraries/SunnaMath.sol";

/// @title MudarabaEngine — Islamic Profit-Loss Sharing Engine
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Implements the Mudaraba contract: funder provides capital, manager
///         provides effort. Profit is shared per agreed ratio. Loss is borne by
///         funder (capital) and manager (effort — recorded as Burned M-Effort).
/// @dev Core formula: P = max(0, finalBalance - capital).
///      All arithmetic uses multiply-before-divide via SunnaMath.
///      Settlement is atomic: calculate → transfer → emit in one transaction.
/// @custom:security-contact abdulwahed.mansour@protonmail.com
/// @custom:invariant Ghunm-bil-Ghurm: funderPayout + managerPayout == finalBalance.
contract MudarabaEngine is ReentrancyGuard {
    // ═══════════════════════════════════════════════════════════════
    //  Sunna Protocol — Mudaraba Engine
    //  Authored by Abdulwahed Mansour / Sweden — February 2026
    //
    //  The Arabic word "Mudaraba" (مضاربة) describes a partnership
    //  where one party provides capital and the other provides labor.
    //  This is perhaps the oldest form of venture capital in human
    //  history — predating modern finance by over a millennium.
    //
    //  The principle governing Mudaraba is Ghunm bil-Ghurm:
    //  "Whoever gains must also bear the risk of loss."
    //
    //  In this engine:
    //  - The funder risks capital. On loss, they lose money.
    //  - The manager risks effort. On loss, their JHD is burned.
    //  - Neither party can externalize loss to the other.
    //  - The code enforces this. Not a contract. Not a promise. Code.
    //
    //  Abdulwahed Mansour / Sweden — Invariant Labs
    //  Original concept: Asymmetric Deficit Socialization (ADS)
    // ═══════════════════════════════════════════════════════════════

    using SafeERC20 for IERC20;
    using SunnaMath for uint256;

    // ──────────────────────────────────────
    // Types
    // ──────────────────────────────────────

    enum ProjectStatus {
        Active,     // Capital deployed, manager working
        Settled,    // Profitable — both parties received shares
        Burned      // Loss occurred — funder lost capital, manager lost effort
    }

    struct Project {
        address funder;
        address manager;
        uint256 capital;
        uint256 finalBalance;
        uint16 funderShareBps;
        uint16 managerShareBps;
        ProjectStatus status;
        uint256 createdAt;
        uint256 settledAt;
    }

    // ──────────────────────────────────────
    // Errors
    // ──────────────────────────────────────

    error InvalidProfitSplit(uint16 funderBps, uint16 managerBps);
    error InvalidCapitalAmount();
    error ProjectAlreadySettled(uint256 projectId);
    error ProjectNotFound(uint256 projectId);
    error NotProjectManager(address caller, address expected);
    error ZeroAddress();
    error InsufficientBalance(uint256 required, uint256 available);
    error FinalBalanceExceedsContractBalance(uint256 finalBalance, uint256 available);

    // ──────────────────────────────────────
    // Events
    // ──────────────────────────────────────

    event ProjectCreated(
        uint256 indexed projectId,
        address indexed funder,
        address indexed manager,
        uint256 capital,
        uint16 funderShareBps
    );

    event ProjectSettled(
        uint256 indexed projectId,
        uint256 finalBalance,
        uint256 netProfit,
        uint256 funderPayout,
        uint256 managerPayout
    );

    event EffortBurnTriggered(
        uint256 indexed projectId,
        address indexed manager
    );

    // ──────────────────────────────────────
    // State
    // ──────────────────────────────────────

    IERC20 public immutable stablecoin;
    uint256 public projectCount;
    mapping(uint256 => Project) public projects;

    /// @notice Total capital currently deployed across all active projects.
    uint256 public totalActiveCapital;

    /// @notice Cumulative settled projects.
    uint256 public totalSettledProjects;

    // ──────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────

    /// @param _stablecoin The stablecoin used for capital (e.g., USDC).
    constructor(address _stablecoin) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
    }

    // ──────────────────────────────────────
    // Project Lifecycle
    // ──────────────────────────────────────

    /// @notice Create a new Mudaraba project.
    /// @dev Funder deposits capital. Profit split must sum to 10000 bps.
    /// @param manager Address of the manager (Mudarib).
    /// @param capital Amount of stablecoin to commit.
    /// @param funderBps Funder's share of profit in basis points.
    /// @param managerBps Manager's share of profit in basis points.
    /// @return projectId The unique identifier for the created project.
    function createProject(
        address manager,
        uint256 capital,
        uint16 funderBps,
        uint16 managerBps
    ) external nonReentrant returns (uint256 projectId) {
        // Validation
        if (manager == address(0)) revert ZeroAddress();
        if (capital == 0) revert InvalidCapitalAmount();
        if (funderBps + managerBps != 10_000) {
            revert InvalidProfitSplit(funderBps, managerBps);
        }

        projectId = projectCount++;

        projects[projectId] = Project({
            funder: msg.sender,
            manager: manager,
            capital: capital,
            finalBalance: 0,
            funderShareBps: funderBps,
            managerShareBps: managerBps,
            status: ProjectStatus.Active,
            createdAt: block.timestamp,
            settledAt: 0
        });

        totalActiveCapital += capital;

        // Transfer capital from funder to this contract
        stablecoin.safeTransferFrom(msg.sender, address(this), capital);

        emit ProjectCreated(projectId, msg.sender, manager, capital, funderBps);
    }

    /// @notice Settle a project — distribute profit or record loss.
    /// @dev CRITICAL INVARIANT: funderPayout + managerPayout == finalBalance.
    ///      This must hold for every settlement. No funds created or destroyed.
    ///
    ///      Profit case:
    ///        profit = finalBalance - capital
    ///        funderPayout = capital + bpsOf(profit, funderBps)
    ///        managerPayout = bpsOf(profit, managerBps)
    ///
    ///      Loss case:
    ///        funderPayout = finalBalance  (bears material loss)
    ///        managerPayout = 0            (bears effort loss — Burned M-Effort)
    ///
    /// @param projectId The project to settle.
    /// @param finalBalance The verified final balance of the investment.
    function settle(uint256 projectId, uint256 finalBalance) external nonReentrant {
        Project storage proj = projects[projectId];

        // Checks
        if (proj.funder == address(0)) revert ProjectNotFound(projectId);
        if (proj.status != ProjectStatus.Active) revert ProjectAlreadySettled(projectId);
        if (msg.sender != proj.manager) {
            revert NotProjectManager(msg.sender, proj.manager);
        }

        uint256 contractBalance = stablecoin.balanceOf(address(this));
        if (finalBalance > contractBalance) {
            revert FinalBalanceExceedsContractBalance(finalBalance, contractBalance);
        }

        // BUG-002 fix: cap finalBalance to prevent draining other projects' capital.
        // Available = contractBalance - (totalActiveCapital - this project's capital)
        uint256 otherProjectsCapital = totalActiveCapital - proj.capital;
        uint256 availableForProject = contractBalance - otherProjectsCapital;
        if (finalBalance > availableForProject) {
            revert InsufficientBalance(finalBalance, availableForProject);
        }

        // Effects
        proj.finalBalance = finalBalance;
        proj.settledAt = block.timestamp;
        totalActiveCapital -= proj.capital;
        totalSettledProjects++;

        uint256 funderPayout;
        uint256 managerPayout;
        uint256 netProfit;

        if (finalBalance > proj.capital) {
            // ══════════════════════════════════════════════════
            // PROFIT CASE — Both parties share the gain
            // ══════════════════════════════════════════════════
            proj.status = ProjectStatus.Settled;

            netProfit = finalBalance - proj.capital;

            // CRITICAL: multiply before divide to prevent precision loss.
            // BUG-003 fix: compute manager share first, assign remainder to funder.
            // This ensures funderPayout + managerPayout == finalBalance exactly.
            managerPayout = netProfit.bpsOf(proj.managerShareBps);
            funderPayout = finalBalance - managerPayout;

            // Interactions — transfer to both parties
            stablecoin.safeTransfer(proj.funder, funderPayout);
            if (managerPayout > 0) {
                stablecoin.safeTransfer(proj.manager, managerPayout);
            }
        } else {
            // ══════════════════════════════════════════════════
            // LOSS CASE — Ghunm bil-Ghurm in action
            // Funder bears material loss (receives less than capital)
            // Manager bears effort loss (JHD burned via SunnaLedger)
            // Manager receives ZERO. This is by design, not by bug.
            //
            // Abdulwahed Mansour / Sweden — this settlement logic
            // is the mathematical enforcement of a 1400-year-old
            // ethical principle. The absence of a transfer to the
            // manager is the most important line in this function.
            // ══════════════════════════════════════════════════
            proj.status = ProjectStatus.Burned;

            funderPayout = finalBalance;
            managerPayout = 0;

            // Interaction — funder receives whatever remains
            if (funderPayout > 0) {
                stablecoin.safeTransfer(proj.funder, funderPayout);
            }

            emit EffortBurnTriggered(projectId, proj.manager);
        }

        emit ProjectSettled(projectId, finalBalance, netProfit, funderPayout, managerPayout);
    }

    // ──────────────────────────────────────
    // View Functions
    // ──────────────────────────────────────

    /// @notice Get full project details.
    function getProject(uint256 projectId) external view returns (Project memory) {
        return projects[projectId];
    }

    /// @notice Check if a project is still active.
    function isActive(uint256 projectId) external view returns (bool) {
        return projects[projectId].status == ProjectStatus.Active;
    }
}
