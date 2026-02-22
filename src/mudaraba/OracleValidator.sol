// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title OracleValidator — Price Feed Safety
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Prevents stale oracle data exploitation (inspired by Moonwell audit)
contract OracleValidator {

    error StalePrice(uint256 updatedAt, uint256 staleness);
    error InvalidRound(uint80 answeredInRound, uint80 roundId);
    error ZeroPrice();
    error NegativePrice();

    uint256 public constant MAX_STALENESS = 3600; // 1 hour

    /// @notice Get validated price — reverts if stale or invalid
    function getValidatedPrice(
        AggregatorV3Interface feed
    ) external view returns (uint256 price, uint8 decimals) {
        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = feed.latestRoundData();

        if (answer <= 0) revert NegativePrice();
        if (answeredInRound < roundId) revert InvalidRound(answeredInRound, roundId);
        if (block.timestamp - updatedAt > MAX_STALENESS) {
            revert StalePrice(updatedAt, block.timestamp - updatedAt);
        }

        price = uint256(answer);
        decimals = feed.decimals();
    }
}
