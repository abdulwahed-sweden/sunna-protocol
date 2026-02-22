// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IMudarabaEngine — Mudaraba Engine Interface
/// @author Abdulwahed Mansour — Sunna Protocol
interface IMudarabaEngine {
    function createProject(address manager, uint256 capital, uint16 funderBps, uint16 managerBps) external returns (uint256 projectId);
    function settle(uint256 projectId, uint256 finalBalance) external;
    function projectCount() external view returns (uint256);
}
