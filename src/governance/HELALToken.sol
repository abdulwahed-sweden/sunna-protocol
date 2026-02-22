// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/// @title HELALToken — Ethical Governance Token
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice The governance token of Sunna Protocol. HELAL combines two meanings:
///         Hilal (هلال — crescent, upward trajectory) and Halal (حلال — pure money).
///         Token holders vote on protocol parameters but CANNOT override
///         constitutional invariants protected by ConstitutionalGuard.
/// @dev ERC-20 with ERC20Votes for on-chain governance. Fixed supply.
///      No mint function after deployment — supply is finite by design.
/// @custom:security-contact abdulwahed.mansour@protonmail.com
contract HELALToken is ERC20, ERC20Permit, ERC20Votes {
    // ═══════════════════════════════════════════════════════════════
    //  Sunna Protocol — $HELAL Governance Token
    //  Authored by Abdulwahed Mansour / Sweden — February 2026
    //
    //  HELAL is governance with boundaries. In traditional DeFi,
    //  governance tokens can vote to change anything — including
    //  the safety mechanisms that protect depositors. This is
    //  equivalent to a parliament voting to abolish the constitution.
    //
    //  In Sunna Protocol, HELAL governance is bounded by the
    //  ConstitutionalGuard. Token holders can:
    //    - Adjust fee rates (within bounds)
    //    - Add assets to the halal whitelist
    //    - Approve new protocols for the Shield
    //    - Modify JHD weights (within bounds)
    //
    //  Token holders CANNOT:
    //    - Disable solvency checks (SE-1)
    //    - Enable fee extraction during loss (PY-1)
    //    - Remove proportional loss sharing (SD-1)
    //    - Override any constitutional invariant
    //
    //  The name HELAL carries dual meaning in Arabic:
    //    هلال (Hilal) = Crescent moon, symbol of growth
    //    حلال (Halal) = Permissible, pure, clean money
    //
    //  Abdulwahed Mansour / Sweden — Invariant Labs
    // ═══════════════════════════════════════════════════════════════

    /// @notice Total supply: 100 million HELAL tokens.
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 1e18;

    /// @param _treasury The address that receives the initial supply.
    constructor(address _treasury)
        ERC20("HELAL", "HELAL")
        ERC20Permit("HELAL")
    {
        require(_treasury != address(0), "SUNNA: zero treasury");
        _mint(_treasury, INITIAL_SUPPLY);
    }

    // ──────────────────────────────────────
    // Required Overrides
    // ──────────────────────────────────────

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
