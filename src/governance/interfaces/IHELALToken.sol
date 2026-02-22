// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IHELALToken — HELAL Governance Token Interface
/// @author Abdulwahed Mansour — Sunna Protocol
/// @custom:security-contact abdulwahed.mansour@protonmail.com
interface IHELALToken {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function governance() external view returns (address);
}
