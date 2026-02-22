// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {OracleValidator, IAggregatorV3} from "../../src/mudaraba/OracleValidator.sol";

contract MockAggregator is IAggregatorV3 {
    int256 public mockAnswer;
    uint256 public mockUpdatedAt;
    uint80 public mockRoundId;
    uint80 public mockAnsweredInRound;

    function setMockData(int256 _answer, uint256 _updatedAt, uint80 _roundId, uint80 _answeredInRound) external {
        mockAnswer = _answer;
        mockUpdatedAt = _updatedAt;
        mockRoundId = _roundId;
        mockAnsweredInRound = _answeredInRound;
    }

    function decimals() external pure returns (uint8) { return 8; }
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (mockRoundId, mockAnswer, 0, mockUpdatedAt, mockAnsweredInRound);
    }
}

contract OracleValidatorTest is Test {
    OracleValidator validator;
    MockAggregator aggregator;

    function setUp() public {
        validator = new OracleValidator(3600);
        aggregator = new MockAggregator();
    }

    // ── getValidatedPrice: success ───────────────────────────────────

    function test_getValidatedPrice_success() public {
        int256 expectedAnswer = 100_000_000_000; // 1000 USD with 8 decimals

        aggregator.setMockData(
            expectedAnswer,
            block.timestamp, // fresh price
            1,               // roundId
            1                // answeredInRound == roundId (valid)
        );

        (uint256 price, uint8 decimals, ) = validator.getValidatedPrice(address(aggregator));

        assertEq(price, uint256(expectedAnswer), "price should match oracle answer");
        assertEq(decimals, 8, "decimals should be 8");
    }

    // ── getValidatedPrice: negative price reverts ────────────────────

    function test_negativePrice_reverts() public {
        aggregator.setMockData(
            -1,              // negative price
            block.timestamp,
            1,
            1
        );

        vm.expectRevert(abi.encodeWithSelector(OracleValidator.InvalidOraclePrice.selector, int256(-1)));
        validator.getValidatedPrice(address(aggregator));
    }

    // ── getValidatedPrice: stale price reverts ───────────────────────

    function test_stalePrice_reverts() public {
        vm.warp(10_000);
        uint256 staleTime = block.timestamp - 7200; // 2 hours ago, exceeds maxStaleness (3600)

        aggregator.setMockData(
            100_000_000_000,
            staleTime,
            1,
            1
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                OracleValidator.StaleOracleData.selector,
                staleTime,
                block.timestamp,
                3600
            )
        );
        validator.getValidatedPrice(address(aggregator));
    }

    // ── getValidatedPrice: invalid round reverts ─────────────────────

    function test_invalidRound_reverts() public {
        aggregator.setMockData(
            100_000_000_000,
            block.timestamp,
            5,  // roundId = 5
            4   // answeredInRound = 4 < roundId => invalid
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                OracleValidator.IncompleteOracleRound.selector,
                4, // answeredInRound
                5  // roundId
            )
        );
        validator.getValidatedPrice(address(aggregator));
    }
}
