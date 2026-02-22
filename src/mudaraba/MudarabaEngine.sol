// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title MudarabaEngine — Profit-Loss Sharing Engine
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Implements Islamic Mudaraba: funder provides capital, manager provides effort
/// @dev Enforces: P = max(0, R - L). Multiply-before-divide for precision.
contract MudarabaEngine is ReentrancyGuard {

    error InvalidShares();
    error ProjectAlreadySettled();
    error OnlyManager();

    event ProjectCreated(uint256 indexed projectId, address funder, address manager, uint256 capital);
    event ProjectSettled(uint256 indexed projectId, uint256 finalBalance, uint256 profit, uint256 funderShare, uint256 managerShare);
    event EffortBurned(uint256 indexed projectId, address manager, uint256 jhdBurned);

    struct Project {
        address funder;
        address manager;
        uint256 capital;
        uint256 finalBalance;
        uint16 funderShareBps;
        uint16 managerShareBps;
        bool settled;
    }

    IERC20 public immutable stablecoin;
    uint256 public projectCount;
    mapping(uint256 => Project) public projects;

    constructor(address _stablecoin) {
        stablecoin = IERC20(_stablecoin);
    }

    /// @notice Create a new Mudaraba project
    function createProject(
        address manager,
        uint256 capital,
        uint16 funderBps,
        uint16 managerBps
    ) external nonReentrant returns (uint256 projectId) {
        if (funderBps + managerBps != 10_000) revert InvalidShares();

        projectId = projectCount++;
        projects[projectId] = Project({
            funder: msg.sender,
            manager: manager,
            capital: capital,
            finalBalance: 0,
            funderShareBps: funderBps,
            managerShareBps: managerBps,
            settled: false
        });

        SafeERC20.safeTransferFrom(stablecoin, msg.sender, address(this), capital);
        emit ProjectCreated(projectId, msg.sender, manager, capital);
    }

    /// @notice Settle project — distribute profit or record loss
    /// @dev Core formula: P = max(0, finalBalance - capital)
    function settle(uint256 projectId, uint256 finalBalance) external nonReentrant {
        Project storage proj = projects[projectId];
        if (proj.settled) revert ProjectAlreadySettled();
        if (msg.sender != proj.manager) revert OnlyManager();

        proj.finalBalance = finalBalance;
        proj.settled = true;

        SafeERC20.safeTransferFrom(stablecoin, msg.sender, address(this), finalBalance);

        if (finalBalance > proj.capital) {
            // PROFIT CASE
            uint256 profit = finalBalance - proj.capital;
            uint256 funderProfit = (profit * proj.funderShareBps) / 10_000;
            uint256 managerProfit = (profit * proj.managerShareBps) / 10_000;

            uint256 funderTotal = proj.capital + funderProfit;

            SafeERC20.safeTransfer(stablecoin, proj.funder, funderTotal);
            SafeERC20.safeTransfer(stablecoin, proj.manager, managerProfit);

            emit ProjectSettled(projectId, finalBalance, profit, funderTotal, managerProfit);
        } else {
            // LOSS CASE — Funder bears material loss, Manager bears effort loss
            SafeERC20.safeTransfer(stablecoin, proj.funder, finalBalance);
            emit ProjectSettled(projectId, finalBalance, 0, finalBalance, 0);
            emit EffortBurned(projectId, proj.manager, 0);
        }
    }
}
