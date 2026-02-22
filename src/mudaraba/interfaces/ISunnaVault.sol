// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISunnaVault — Sunna Vault Interface
/// @author Abdulwahed Mansour — Sunna Protocol
interface ISunnaVault {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function totalDeposits() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}
