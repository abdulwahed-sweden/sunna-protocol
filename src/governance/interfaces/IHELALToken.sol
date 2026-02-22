// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IHELALToken — HELAL Governance Token Interface
/// @author Abdulwahed Mansour — Sunna Protocol
interface IHELALToken {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function governance() external view returns (address);
}
