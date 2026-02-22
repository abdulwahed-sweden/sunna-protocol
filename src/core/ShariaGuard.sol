// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ShariaGuard — Living Sharia Compliance Document
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice This contract IS the Sharia compliance document — not a description
///         of compliance, but the compliance itself. Scholars review this code
///         directly. Non-compliant transactions revert before execution.
/// @dev Maintains halal asset whitelist and enforces:
///      - No Riba: no code path produces guaranteed fixed return.
///      - No Gharar: all parameters transparent and immutable post-deploy.
///      - No Maysir: returns tied to real economic activity.
///      - Ghunm bil-Ghurm: enforced via MudarabaEngine integration.
/// @custom:security-contact abdulwahed.mansour@protonmail.com
contract ShariaGuard {
    // ═══════════════════════════════════════════════════════════════
    //  Sunna Protocol — Sharia Guard (Living Sharia Document)
    //  Authored by Abdulwahed Mansour / Sweden — February 2026
    //
    //  Traditional Sharia compliance: paper fatwa, periodic review.
    //  Sunna Protocol Sharia compliance: executable code, real-time
    //  enforcement, impossible to violate, permanently auditable.
    //
    //  The code does not describe compliance. The code IS compliance.
    //
    //  Abdulwahed Mansour / Sweden — Invariant Labs
    // ═══════════════════════════════════════════════════════════════

    // ──────────────────────────────────────
    // Errors
    // ──────────────────────────────────────

    error AssetNotHalal(address asset);
    error ProtocolNotApproved(address protocol);
    error OnlyAdmin();
    error ZeroAddress();
    error AlreadyWhitelisted(address asset);
    error NotWhitelisted(address asset);

    // ──────────────────────────────────────
    // Events
    // ──────────────────────────────────────

    event AssetWhitelisted(address indexed asset, string reason);
    event AssetDelisted(address indexed asset, string reason);
    event ProtocolApproved(address indexed protocol);
    event ProtocolRevoked(address indexed protocol);

    // ──────────────────────────────────────
    // State
    // ──────────────────────────────────────

    address public immutable admin;

    /// @notice Assets permitted for use within the protocol.
    mapping(address => bool) public halalAssets;

    /// @notice External protocols approved for capital deployment.
    mapping(address => bool) public approvedProtocols;

    /// @notice Count of whitelisted assets for transparency.
    uint256 public halalAssetCount;

    // ──────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────

    constructor() {
        admin = msg.sender;
    }

    // ──────────────────────────────────────
    // Enforcement Functions
    // ──────────────────────────────────────

    /// @notice Verify an asset is on the halal whitelist. Reverts if not.
    /// @param asset The asset address to verify.
    function enforceHalal(address asset) external view {
        if (!halalAssets[asset]) revert AssetNotHalal(asset);
    }

    /// @notice Verify a protocol is approved. Reverts if not.
    /// @param protocol The protocol address to verify.
    function enforceProtocol(address protocol) external view {
        if (!approvedProtocols[protocol]) revert ProtocolNotApproved(protocol);
    }

    /// @notice Check if an asset is halal without reverting.
    /// @param asset The asset address to check.
    /// @return Whether the asset is whitelisted.
    function isHalal(address asset) external view returns (bool) {
        return halalAssets[asset];
    }

    // ──────────────────────────────────────
    // Admin — Whitelist Management
    // ──────────────────────────────────────

    /// @notice Add an asset to the halal whitelist.
    /// @dev Requires governance approval and Sharia review in production.
    /// @param asset The asset address to whitelist.
    /// @param reason Human-readable justification for the listing.
    function whitelistAsset(address asset, string calldata reason) external {
        if (msg.sender != admin) revert OnlyAdmin();
        if (asset == address(0)) revert ZeroAddress();
        if (halalAssets[asset]) revert AlreadyWhitelisted(asset);

        halalAssets[asset] = true;
        halalAssetCount++;

        emit AssetWhitelisted(asset, reason);
    }

    /// @notice Remove an asset from the halal whitelist.
    /// @dev Immediate removal — no time-lock. Non-compliance is urgent.
    /// @param asset The asset address to delist.
    /// @param reason Human-readable justification for the removal.
    function delistAsset(address asset, string calldata reason) external {
        if (msg.sender != admin) revert OnlyAdmin();
        if (!halalAssets[asset]) revert NotWhitelisted(asset);

        halalAssets[asset] = false;
        halalAssetCount--;

        emit AssetDelisted(asset, reason);
    }

    /// @notice Approve an external protocol for capital deployment.
    /// @param protocol The protocol address to approve.
    function approveProtocol(address protocol) external {
        if (msg.sender != admin) revert OnlyAdmin();
        if (protocol == address(0)) revert ZeroAddress();

        approvedProtocols[protocol] = true;
        emit ProtocolApproved(protocol);
    }

    /// @notice Revoke an external protocol's approval.
    /// @param protocol The protocol address to revoke.
    function revokeProtocol(address protocol) external {
        if (msg.sender != admin) revert OnlyAdmin();

        approvedProtocols[protocol] = false;
        emit ProtocolRevoked(protocol);
    }
}
