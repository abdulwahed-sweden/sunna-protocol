// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ShariaGuard — Halal Whitelist & No-Fee-On-Loss Enforcer
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Maintains a whitelist of Sharia-compliant protocols and enforces halal constraints
/// @dev Only whitelisted protocols may be interacted with by the Sunna Protocol engine
contract ShariaGuard {

    error HaramProtocol();
    error UnauthorizedCaller();

    event ProtocolWhitelisted(address protocol);
    event ProtocolDelisted(address protocol);

    mapping(address => bool) public halalWhitelist;
    address public immutable admin;

    modifier onlyAdmin() {
        if (msg.sender != admin) revert UnauthorizedCaller();
        _;
    }

    modifier onlyHalal(address protocol) {
        if (!halalWhitelist[protocol]) revert HaramProtocol();
        _;
    }

    constructor(address _admin) {
        admin = _admin;
    }

    /// @notice Add a protocol to the halal whitelist
    /// @param protocol The address of the protocol to whitelist
    function addToWhitelist(address protocol) external onlyAdmin {
        halalWhitelist[protocol] = true;
        emit ProtocolWhitelisted(protocol);
    }

    /// @notice Remove a protocol from the halal whitelist
    /// @param protocol The address of the protocol to delist
    function removeFromWhitelist(address protocol) external onlyAdmin {
        halalWhitelist[protocol] = false;
        emit ProtocolDelisted(protocol);
    }

    /// @notice Check if a protocol is halal (whitelisted)
    /// @param protocol The address of the protocol to check
    /// @return True if the protocol is whitelisted
    function isHalal(address protocol) external view returns (bool) {
        return halalWhitelist[protocol];
    }
}
