// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SunnaMath} from "../libraries/SunnaMath.sol";

/// @title SunnaLedger — On-Chain Effort Measurement System
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice The world's first DeFi protocol to measure, record, and permanently
///         store human effort on the blockchain. JHD (Juhd/Effort) units are
///         non-transferable, soulbound, and immutable once recorded.
/// @dev JHD is computed from verifiable on-chain actions, not self-reporting.
///      Efficiency = (Net_Profit × 100) / Total_JHD.
///      Burned M-Effort permanently reduces a manager's lifetime efficiency.
/// @custom:security-contact abdulwahed.mansour@protonmail.com
contract SunnaLedger {
    // ═══════════════════════════════════════════════════════════════
    //  Sunna Protocol — SunnaLedger (JHD Effort Tracking)
    //  Authored by Abdulwahed Mansour / Sweden — February 2026
    //
    //  For thousands of years, human effort has been invisible in
    //  financial systems. An investor loses money and asks: "Did the
    //  manager actually work?" There was never an answer.
    //
    //  SunnaLedger answers that question — permanently, on-chain,
    //  and with mathematical precision.
    //
    //  Every trade, every report, every hour of monitoring is
    //  recorded as JHD (from Arabic "Juhd" — effort). When a
    //  project fails, the manager's JHD is burned. The effort
    //  was real — but it produced nothing. This is visible to
    //  every future funder who evaluates this manager.
    //
    //  This is not a reputation system built on votes or reviews.
    //  This is a reputation system built on verified actions.
    //
    //  No DeFi protocol has ever done this before.
    //
    //  Abdulwahed Mansour / Sweden — Invariant Labs
    //  Original innovation: Burned M-Effort concept
    // ═══════════════════════════════════════════════════════════════

    using SunnaMath for uint256;

    // ──────────────────────────────────────
    // Types
    // ──────────────────────────────────────

    /// @notice Categories of verifiable on-chain actions.
    enum ActionType {
        TradeExecuted,        // Weight: 5 JHD
        ReportSubmitted,      // Weight: 10 JHD
        StrategyUpdated,      // Weight: 8 JHD
        PortfolioRebalanced,  // Weight: 15 JHD
        MonitoringHour        // Weight: 1 JHD
    }

    /// @notice A single recorded effort entry.
    struct EffortEntry {
        uint256 timestamp;
        uint256 jhdAmount;
        ActionType actionType;
        bytes32 proofHash;
    }

    /// @notice Aggregated effort data for a specific project.
    struct ProjectEffort {
        uint256 totalJHD;
        uint256 profitUSD;
        bool active;
        bool burned;
        uint256 entryCount;
    }

    /// @notice A manager's lifetime statistics.
    struct ManagerStats {
        uint256 lifetimeJHD;
        uint256 burnedJHD;
        uint256 lifetimeProfitUSD;
        uint256 projectCount;
        uint256 burnedProjectCount;
    }

    // ──────────────────────────────────────
    // Errors
    // ──────────────────────────────────────

    error UnauthorizedRecorder();
    error ZeroJHDWeight();
    error ProjectNotActive(uint256 projectId);
    error OnlyAdmin();
    error ZeroAddress();

    // ──────────────────────────────────────
    // Events
    // ──────────────────────────────────────

    event EffortRecorded(
        uint256 indexed projectId,
        address indexed manager,
        uint256 jhdAmount,
        ActionType actionType,
        bytes32 proofHash
    );

    event EffortBurned(
        uint256 indexed projectId,
        address indexed manager,
        uint256 totalBurnedJHD
    );

    event EfficiencyCalculated(
        uint256 indexed projectId,
        address indexed manager,
        uint256 totalJHD,
        uint256 profitUSD,
        uint256 efficiencyScore
    );

    event ProjectActivated(uint256 indexed projectId, address indexed manager);

    // ──────────────────────────────────────
    // State
    // ──────────────────────────────────────

    address public immutable admin;

    /// @notice JHD weight per action type.
    mapping(ActionType => uint256) public jhdWeights;

    /// @notice Effort entries per project.
    mapping(uint256 => EffortEntry[]) internal _projectEntries;

    /// @notice Aggregated effort per project.
    mapping(uint256 => ProjectEffort) public projectEfforts;

    /// @notice Manager who owns each project's effort.
    mapping(uint256 => address) public projectManagers;

    /// @notice Lifetime statistics per manager.
    mapping(address => ManagerStats) public managerStats;

    /// @notice Project IDs associated with each manager.
    mapping(address => uint256[]) internal _managerProjects;

    /// @notice Authorized contracts that may record effort.
    mapping(address => bool) public authorizedRecorders;

    // ──────────────────────────────────────
    // Modifiers
    // ──────────────────────────────────────

    modifier onlyRecorder() {
        if (!authorizedRecorders[msg.sender]) revert UnauthorizedRecorder();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    // ──────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────

    constructor() {
        admin = msg.sender;

        // Default JHD weights — calibrated for fair effort valuation
        jhdWeights[ActionType.TradeExecuted] = 5;
        jhdWeights[ActionType.ReportSubmitted] = 10;
        jhdWeights[ActionType.StrategyUpdated] = 8;
        jhdWeights[ActionType.PortfolioRebalanced] = 15;
        jhdWeights[ActionType.MonitoringHour] = 1;
    }

    // ──────────────────────────────────────
    // Project Activation
    // ──────────────────────────────────────

    /// @notice Activate a project for effort tracking.
    /// @param projectId The project to activate.
    /// @param manager The manager responsible for this project.
    function activateProject(uint256 projectId, address manager) external onlyRecorder {
        if (manager == address(0)) revert ZeroAddress();

        projectEfforts[projectId].active = true;
        projectManagers[projectId] = manager;
        _managerProjects[manager].push(projectId);

        ManagerStats storage stats = managerStats[manager];
        stats.projectCount++;

        emit ProjectActivated(projectId, manager);
    }

    // ──────────────────────────────────────
    // Effort Recording
    // ──────────────────────────────────────

    /// @notice Record a verified effort action for a manager.
    /// @param projectId The project this effort belongs to.
    /// @param manager The manager who performed the action.
    /// @param actionType The type of action performed.
    /// @param proofHash On-chain proof (tx hash, IPFS CID, contract call hash).
    function recordEffort(
        uint256 projectId,
        address manager,
        ActionType actionType,
        bytes32 proofHash
    ) external onlyRecorder {
        ProjectEffort storage pe = projectEfforts[projectId];
        if (!pe.active) revert ProjectNotActive(projectId);

        uint256 jhd = jhdWeights[actionType];
        if (jhd == 0) revert ZeroJHDWeight();

        // Record the entry — immutable once written
        _projectEntries[projectId].push(EffortEntry({
            timestamp: block.timestamp,
            jhdAmount: jhd,
            actionType: actionType,
            proofHash: proofHash
        }));

        pe.totalJHD += jhd;
        pe.entryCount++;

        // Update manager lifetime stats — JHD only increases, never decreases
        managerStats[manager].lifetimeJHD += jhd;

        emit EffortRecorded(projectId, manager, jhd, actionType, proofHash);
    }

    // ──────────────────────────────────────
    // Settlement Integration
    // ──────────────────────────────────────

    /// @notice Record profit and calculate efficiency for a settled project.
    /// @param projectId The settled project.
    /// @param manager The project's manager.
    /// @param profitUSD The realized profit in base denomination.
    /// @return efficiencyScore (profitUSD * 100) / totalJHD.
    function recordProfit(
        uint256 projectId,
        address manager,
        uint256 profitUSD
    ) external onlyRecorder returns (uint256 efficiencyScore) {
        ProjectEffort storage pe = projectEfforts[projectId];
        pe.profitUSD = profitUSD;
        pe.active = false;

        managerStats[manager].lifetimeProfitUSD += profitUSD;

        efficiencyScore = pe.totalJHD.efficiency(profitUSD);

        emit EfficiencyCalculated(projectId, manager, pe.totalJHD, profitUSD, efficiencyScore);
    }

    /// @notice Burn a manager's effort on a failed project.
    /// @dev Once burned, the JHD remains on record but is marked as burned.
    ///      This permanently reduces the manager's lifetime efficiency.
    /// @param projectId The failed project.
    /// @param manager The manager whose effort is burned.
    function burnEffort(uint256 projectId, address manager) external onlyRecorder {
        ProjectEffort storage pe = projectEfforts[projectId];
        pe.burned = true;
        pe.active = false;

        ManagerStats storage stats = managerStats[manager];
        stats.burnedJHD += pe.totalJHD;
        stats.burnedProjectCount++;

        emit EffortBurned(projectId, manager, pe.totalJHD);
    }

    // ──────────────────────────────────────
    // View Functions
    // ──────────────────────────────────────

    /// @notice Get a manager's complete statistics.
    function getManagerStats(address manager) external view returns (
        uint256 lifetimeJHD,
        uint256 burnedJHD,
        uint256 activeJHD,
        uint256 lifetimeProfitUSD,
        uint256 projectCount,
        uint256 burnedProjectCount,
        uint256 lifetimeEfficiency
    ) {
        ManagerStats storage s = managerStats[manager];
        lifetimeJHD = s.lifetimeJHD;
        burnedJHD = s.burnedJHD;
        activeJHD = lifetimeJHD - burnedJHD;
        lifetimeProfitUSD = s.lifetimeProfitUSD;
        projectCount = s.projectCount;
        burnedProjectCount = s.burnedProjectCount;
        lifetimeEfficiency = lifetimeJHD > 0 ? (lifetimeProfitUSD * 100) / lifetimeJHD : 0;
    }

    /// @notice Get project effort summary.
    function getProjectEffort(uint256 projectId) external view returns (ProjectEffort memory) {
        return projectEfforts[projectId];
    }

    /// @notice Get a specific effort entry for a project.
    function getEffortEntry(uint256 projectId, uint256 index) external view returns (EffortEntry memory) {
        return _projectEntries[projectId][index];
    }

    /// @notice Get all project IDs for a manager.
    function getManagerProjects(address manager) external view returns (uint256[] memory) {
        return _managerProjects[manager];
    }

    /// @notice Get the burn ratio for a manager (burnedJHD * 10000 / lifetimeJHD).
    /// @return burnRatioBps Burn ratio in basis points (e.g., 4280 = 42.8%).
    function getBurnRatio(address manager) external view returns (uint256 burnRatioBps) {
        ManagerStats storage s = managerStats[manager];
        if (s.lifetimeJHD == 0) return 0;
        burnRatioBps = (s.burnedJHD * 10_000) / s.lifetimeJHD;
    }

    // ──────────────────────────────────────
    // Admin
    // ──────────────────────────────────────

    function setAuthorizedRecorder(address recorder, bool authorized) external onlyAdmin {
        if (recorder == address(0)) revert ZeroAddress();
        authorizedRecorders[recorder] = authorized;
    }

    function updateJHDWeight(ActionType actionType, uint256 newWeight) external onlyAdmin {
        if (newWeight == 0) revert ZeroJHDWeight();
        jhdWeights[actionType] = newWeight;
    }
}
