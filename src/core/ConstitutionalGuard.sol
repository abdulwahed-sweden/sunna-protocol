// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ConstitutionalGuard — Immutable Invariant Protection
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Ensures core protocol invariants are registered and cannot be altered
/// @dev Invariants are stored as keccak256 hashes and verified on-chain
contract ConstitutionalGuard {

    error InvariantNotRegistered();
    error UnauthorizedGuardian();

    event InvariantRegistered(bytes32 invariantHash);
    event InvariantVerified(bytes32 invariantHash);

    mapping(bytes32 => bool) public invariantRegistry;
    address public immutable guardian;

    modifier onlyGuardian() {
        if (msg.sender != guardian) revert UnauthorizedGuardian();
        _;
    }

    constructor(address _guardian) {
        guardian = _guardian;
    }

    /// @notice Register a new invariant hash — only callable by guardian
    /// @param invariantHash The keccak256 hash of the invariant to register
    function registerInvariant(bytes32 invariantHash) external onlyGuardian {
        invariantRegistry[invariantHash] = true;
        emit InvariantRegistered(invariantHash);
    }

    /// @notice Check if an invariant is registered
    /// @param invariantHash The keccak256 hash of the invariant to check
    /// @return True if the invariant is registered
    function isRegistered(bytes32 invariantHash) external view returns (bool) {
        return invariantRegistry[invariantHash];
    }

    /// @notice Verify an invariant is registered — reverts if not
    /// @param invariantHash The keccak256 hash of the invariant to verify
    function verifyInvariant(bytes32 invariantHash) external view {
        if (!invariantRegistry[invariantHash]) revert InvariantNotRegistered();
        // Note: event cannot be emitted in a view function.
        // InvariantVerified is emitted by non-view wrapper callers.
    }
}
