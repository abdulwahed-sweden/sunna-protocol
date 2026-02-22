// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISunnaLedger — Sunna Ledger Interface
/// @author Abdulwahed Mansour — Sunna Protocol
/// @custom:security-contact abdulwahed.mansour@protonmail.com
interface ISunnaLedger {
    function recordEffort(uint256 projectId, address manager, uint8 actionType, bytes32 proofHash) external;
    function burnEffort(uint256 projectId, address manager, string calldata reason) external;
    function recordProfitAndEfficiency(uint256 projectId, address manager, uint256 profitUSD) external returns (uint256 efficiency);
    function getManagerStats(address manager) external view returns (uint256 totalJHD, uint256 burnedJHD, uint256 activeJHD, uint256 totalProjects, uint256 totalProfitUSD, uint256 lifetimeEfficiency);
    function getProjectEffort(uint256 projectId) external view returns (uint256 totalJHD, uint256 profitUSD, bool burned, uint256 efficiency, uint256 entryCount);
}
