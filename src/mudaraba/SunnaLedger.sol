// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SunnaLedger — On-Chain Effort Measurement System
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice World's first DeFi protocol to measure and record human effort on-chain
/// @dev JHD (Juhd/Effort) units are immutable once recorded. Efficiency = Profit/JHD × 100
contract SunnaLedger {

    error UnauthorizedRecorder();
    error ProjectDoesNotExist();
    error InvalidJHDAmount();

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
        uint256 totalJHD,
        string reason
    );

    event EfficiencyCalculated(
        uint256 indexed projectId,
        address indexed manager,
        uint256 totalJHD,
        uint256 profitUSD,
        uint256 efficiencyScore
    );

    enum ActionType {
        TRADE_EXECUTED,
        REPORT_SUBMITTED,
        STRATEGY_UPDATED,
        PORTFOLIO_REBALANCED,
        MONITORING_HOUR
    }

    struct EffortEntry {
        uint256 timestamp;
        uint256 jhdAmount;
        ActionType actionType;
        bytes32 proofHash;
    }

    struct ManagerProfile {
        uint256 totalJHD;
        uint256 totalProjects;
        uint256 totalProfitUSD;
        uint256 burnedJHD;
        uint256[] projectIds;
    }

    struct ProjectEffort {
        uint256 totalJHD;
        uint256 profitUSD;
        bool burned;
        EffortEntry[] entries;
    }

    mapping(ActionType => uint256) public jhdWeights;
    mapping(address => ManagerProfile) public managerProfiles;
    mapping(uint256 => ProjectEffort) public projectEfforts;
    mapping(address => bool) public authorizedRecorders;

    address public immutable admin;

    modifier onlyRecorder() {
        if (!authorizedRecorders[msg.sender]) revert UnauthorizedRecorder();
        _;
    }

    constructor() {
        admin = msg.sender;

        jhdWeights[ActionType.TRADE_EXECUTED] = 5;
        jhdWeights[ActionType.REPORT_SUBMITTED] = 10;
        jhdWeights[ActionType.STRATEGY_UPDATED] = 8;
        jhdWeights[ActionType.PORTFOLIO_REBALANCED] = 15;
        jhdWeights[ActionType.MONITORING_HOUR] = 1;
    }

    /// @notice Record effort for a manager on a project
    function recordEffort(
        uint256 projectId,
        address manager,
        ActionType actionType,
        bytes32 proofHash
    ) external onlyRecorder {
        uint256 jhd = jhdWeights[actionType];
        if (jhd == 0) revert InvalidJHDAmount();

        ProjectEffort storage pe = projectEfforts[projectId];
        pe.entries.push(EffortEntry({
            timestamp: block.timestamp,
            jhdAmount: jhd,
            actionType: actionType,
            proofHash: proofHash
        }));
        pe.totalJHD += jhd;

        ManagerProfile storage mp = managerProfiles[manager];
        mp.totalJHD += jhd;

        emit EffortRecorded(projectId, manager, jhd, actionType, proofHash);
    }

    /// @notice Mark project effort as burned (project resulted in loss)
    function burnEffort(uint256 projectId, address manager, string calldata reason) external onlyRecorder {
        ProjectEffort storage pe = projectEfforts[projectId];
        pe.burned = true;

        ManagerProfile storage mp = managerProfiles[manager];
        mp.burnedJHD += pe.totalJHD;

        emit EffortBurned(projectId, manager, pe.totalJHD, reason);
    }

    /// @notice Record final profit and calculate efficiency
    function recordProfitAndEfficiency(
        uint256 projectId,
        address manager,
        uint256 profitUSD
    ) external onlyRecorder returns (uint256 efficiency) {
        ProjectEffort storage pe = projectEfforts[projectId];
        pe.profitUSD = profitUSD;

        ManagerProfile storage mp = managerProfiles[manager];
        mp.totalProfitUSD += profitUSD;

        efficiency = pe.totalJHD > 0 ? (profitUSD * 100) / pe.totalJHD : 0;

        emit EfficiencyCalculated(projectId, manager, pe.totalJHD, profitUSD, efficiency);
    }

    /// @notice Get manager's lifetime stats
    function getManagerStats(address manager) external view returns (
        uint256 totalJHD,
        uint256 burnedJHD,
        uint256 activeJHD,
        uint256 totalProjects,
        uint256 totalProfitUSD,
        uint256 lifetimeEfficiency
    ) {
        ManagerProfile storage mp = managerProfiles[manager];
        totalJHD = mp.totalJHD;
        burnedJHD = mp.burnedJHD;
        activeJHD = totalJHD - burnedJHD;
        totalProjects = mp.totalProjects;
        totalProfitUSD = mp.totalProfitUSD;
        lifetimeEfficiency = totalJHD > 0 ? (totalProfitUSD * 100) / totalJHD : 0;
    }

    /// @notice Get project effort details
    function getProjectEffort(uint256 projectId) external view returns (
        uint256 totalJHD,
        uint256 profitUSD,
        bool burned,
        uint256 efficiency,
        uint256 entryCount
    ) {
        ProjectEffort storage pe = projectEfforts[projectId];
        totalJHD = pe.totalJHD;
        profitUSD = pe.profitUSD;
        burned = pe.burned;
        efficiency = totalJHD > 0 ? (profitUSD * 100) / totalJHD : 0;
        entryCount = pe.entries.length;
    }

    function setAuthorizedRecorder(address recorder, bool authorized) external {
        require(msg.sender == admin, "SUNNA: only admin");
        authorizedRecorders[recorder] = authorized;
    }
}
