// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAggregatorV3 — Minimal Chainlink Oracle Interface
/// @author Abdulwahed Mansour — Sunna Protocol
/// @dev Minimal interface to avoid heavy external dependency on Chainlink.
/// @custom:security-contact abdulwahed.mansour@protonmail.com
interface IAggregatorV3 {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    function decimals() external view returns (uint8);
}

/// @title OracleValidator — Price Feed Safety Layer
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Validates oracle price data to prevent stale, zero, or manipulated
///         prices from propagating through the protocol. Inspired by real
///         vulnerabilities discovered in production DeFi protocols.
/// @dev Performs three independent checks on every price query:
///      1. Price positivity (rejects zero and negative).
///      2. Round completeness (answeredInRound >= roundId).
///      3. Freshness (timestamp within staleness threshold).
///      All three must pass. Any single failure causes a revert.
/// @custom:security-contact abdulwahed.mansour@protonmail.com
contract OracleValidator {
    // ═══════════════════════════════════════════════════════════════
    //  Sunna Protocol — Oracle Validator
    //  Authored by Abdulwahed Mansour / Sweden — February 2026
    //
    //  Oracle manipulation is the silent killer of DeFi protocols.
    //  A stale price feed means the protocol is making decisions
    //  based on information that no longer reflects reality.
    //
    //  During the Moonwell security audit, I discovered that
    //  incomplete oracle round checks allowed stale data to
    //  propagate, creating phantom yield conditions. This contract
    //  is the direct result of that discovery.
    //
    //  Three checks. Three independent failure modes. All three
    //  must pass. This is defense in depth for price data.
    //
    //  Abdulwahed Mansour / Sweden — Invariant Labs
    //  Discovery origin: Moonwell Oracle Vulnerability (M-01, M-02)
    // ═══════════════════════════════════════════════════════════════

    // ──────────────────────────────────────
    // Errors
    // ──────────────────────────────────────

    /// @notice Oracle returned a zero or negative price.
    error InvalidOraclePrice(int256 answer);

    /// @notice Oracle round data is incomplete (answer from a previous round).
    error IncompleteOracleRound(uint80 answeredInRound, uint80 roundId);

    /// @notice Oracle data is stale beyond acceptable threshold.
    error StaleOracleData(uint256 updatedAt, uint256 currentTime, uint256 maxStaleness);

    /// @notice Zero address provided for oracle feed.
    error ZeroAddress();

    // ──────────────────────────────────────
    // Events
    // ──────────────────────────────────────

    event PriceValidated(address indexed feed, uint256 price, uint256 updatedAt);
    event StalenessUpdated(uint256 previousSeconds, uint256 newSeconds);

    // ──────────────────────────────────────
    // State
    // ──────────────────────────────────────

    address public immutable admin;

    /// @notice Maximum acceptable age of oracle data in seconds.
    uint256 public maxStaleness;

    /// @notice Default staleness: 1 hour. Configurable per deployment.
    uint256 public constant DEFAULT_MAX_STALENESS = 3600;

    // ──────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────

    /// @param _maxStaleness Maximum staleness in seconds (0 uses default).
    constructor(uint256 _maxStaleness) {
        admin = msg.sender;
        maxStaleness = _maxStaleness > 0 ? _maxStaleness : DEFAULT_MAX_STALENESS;
    }

    // ──────────────────────────────────────
    // Core Validation
    // ──────────────────────────────────────

    /// @notice Get a validated price from an oracle feed.
    /// @dev Performs all three safety checks. Reverts on any failure.
    /// @param feed The Chainlink-compatible oracle feed address.
    /// @return price The validated positive price as uint256.
    /// @return decimals The number of decimals in the price.
    /// @return updatedAt The timestamp of the price update.
    function getValidatedPrice(
        address feed
    ) external view returns (uint256 price, uint8 decimals, uint256 updatedAt) {
        if (feed == address(0)) revert ZeroAddress();

        IAggregatorV3 oracle = IAggregatorV3(feed);

        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 _updatedAt,
            uint80 answeredInRound
        ) = oracle.latestRoundData();

        // ── CHECK 1: Price must be strictly positive ──
        // A zero price means the oracle has no data.
        // A negative price is physically impossible for asset prices.
        if (answer <= 0) {
            revert InvalidOraclePrice(answer);
        }

        // ── CHECK 2: Round completeness ──
        // If answeredInRound < roundId, the answer is from a previous
        // round and has not been updated for the current round.
        // This is a stale data signal specific to Chainlink.
        if (answeredInRound < roundId) {
            revert IncompleteOracleRound(answeredInRound, roundId);
        }

        // ── CHECK 3: Freshness ──
        // The price must have been updated within the staleness window.
        // A feed that hasn't updated in hours may reflect a defunct oracle.
        if (block.timestamp - _updatedAt > maxStaleness) {
            revert StaleOracleData(_updatedAt, block.timestamp, maxStaleness);
        }

        price = uint256(answer);
        decimals = oracle.decimals();
        updatedAt = _updatedAt;
    }

    /// @notice Validate without returning — pure check, reverts on failure.
    /// @param feed The oracle feed address to validate.
    function validate(address feed) external view {
        if (feed == address(0)) revert ZeroAddress();

        IAggregatorV3 oracle = IAggregatorV3(feed);

        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 _updatedAt,
            uint80 answeredInRound
        ) = oracle.latestRoundData();

        if (answer <= 0) revert InvalidOraclePrice(answer);
        if (answeredInRound < roundId) revert IncompleteOracleRound(answeredInRound, roundId);
        if (block.timestamp - _updatedAt > maxStaleness) {
            revert StaleOracleData(_updatedAt, block.timestamp, maxStaleness);
        }
    }

    // ──────────────────────────────────────
    // Admin
    // ──────────────────────────────────────

    /// @notice Update the maximum staleness threshold.
    /// @param newMaxStaleness New threshold in seconds.
    function setMaxStaleness(uint256 newMaxStaleness) external {
        require(msg.sender == admin, "SUNNA: only admin");
        require(newMaxStaleness >= 60, "SUNNA: staleness too low");

        uint256 previous = maxStaleness;
        maxStaleness = newMaxStaleness;

        emit StalenessUpdated(previous, newMaxStaleness);
    }
}
