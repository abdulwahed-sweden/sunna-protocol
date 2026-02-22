// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISunnaShield — Sunna Shield Interface
/// @author Abdulwahed Mansour — Sunna Protocol
/// @custom:security-contact abdulwahed.mansour@protonmail.com
interface ISunnaShield {
    function repay(uint256 principal, uint256 profit) external;
    function reportLoss(uint256 lossAssets) external;
    function investedAssets() external view returns (uint256);
    function managementFeeBps() external view returns (uint16);
    function engine() external view returns (address);
}
