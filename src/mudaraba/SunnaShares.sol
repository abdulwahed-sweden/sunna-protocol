// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title SunnaShares — Dynamic Investment Shares
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice ERC-20 tokens representing proportional ownership in a Mudaraba
///         project. Share value fluctuates based on actual investment
///         performance — never fixed, reflecting true risk-sharing.
/// @dev Minted on deposit, burned on withdrawal. Only the authorized engine
///      can mint or burn. Transfers are restricted to prevent secondary
///      market speculation that could introduce Gharar.
/// @custom:security-contact abdulwahed.mansour@protonmail.com
contract SunnaShares is ERC20 {
    // ═══════════════════════════════════════════════════════════════
    //  Sunna Protocol — Sunna Shares (Investment Tokens)
    //  Authored by Abdulwahed Mansour / Sweden — February 2026
    //
    //  These shares represent real ownership in a real venture.
    //  Their value rises and falls with the venture's performance.
    //  There is no fixed return. There is no guaranteed yield.
    //  This is by design — fixed returns are Riba.
    //
    //  Abdulwahed Mansour / Sweden — Invariant Labs
    // ═══════════════════════════════════════════════════════════════

    // ──────────────────────────────────────
    // Errors
    // ──────────────────────────────────────

    error OnlyEngine();
    error TransfersRestricted();
    error ZeroAddress();

    // ──────────────────────────────────────
    // State
    // ──────────────────────────────────────

    address public immutable engine;

    /// @notice If true, shares cannot be transferred between users.
    ///         This prevents secondary market speculation (Gharar).
    bool public transfersRestricted;

    // ──────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────

    /// @param _name Token name (e.g., "Sunna Alpha Shares").
    /// @param _symbol Token symbol (e.g., "sALPHA").
    /// @param _engine The authorized engine contract.
    /// @param _restrictTransfers Whether to restrict peer-to-peer transfers.
    constructor(
        string memory _name,
        string memory _symbol,
        address _engine,
        bool _restrictTransfers
    ) ERC20(_name, _symbol) {
        if (_engine == address(0)) revert ZeroAddress();
        engine = _engine;
        transfersRestricted = _restrictTransfers;
    }

    // ──────────────────────────────────────
    // Mint / Burn (Engine Only)
    // ──────────────────────────────────────

    /// @notice Mint shares to a funder upon deposit.
    /// @param to The recipient address.
    /// @param amount The number of shares to mint.
    function mint(address to, uint256 amount) external {
        if (msg.sender != engine) revert OnlyEngine();
        _mint(to, amount);
    }

    /// @notice Burn shares from a funder upon withdrawal.
    /// @param from The address to burn from.
    /// @param amount The number of shares to burn.
    function burn(address from, uint256 amount) external {
        if (msg.sender != engine) revert OnlyEngine();
        _burn(from, amount);
    }

    // ──────────────────────────────────────
    // Transfer Override
    // ──────────────────────────────────────

    /// @dev Override to enforce transfer restrictions when enabled.
    ///      The engine can always transfer (needed for settlement).
    function _update(address from, address to, uint256 value) internal override {
        if (transfersRestricted) {
            // Allow mint (from == 0), burn (to == 0), and engine transfers
            bool isMint = from == address(0);
            bool isBurn = to == address(0);
            bool isEngine = msg.sender == engine;

            if (!isMint && !isBurn && !isEngine) {
                revert TransfersRestricted();
            }
        }

        super._update(from, to, value);
    }
}
