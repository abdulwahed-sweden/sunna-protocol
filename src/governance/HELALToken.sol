// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import {IHELALToken} from "./interfaces/IHELALToken.sol";

/// @title HELALToken — HELAL Governance Token
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice ERC-20 governance token for the Sunna Protocol with capped supply
contract HELALToken is ERC20, ERC20Permit, IHELALToken {
    // ──────────────────────────────────────────────
    //  Errors
    // ──────────────────────────────────────────────
    error UnauthorizedGovernance();
    error MaxSupplyExceeded();

    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────
    event GovernanceMint(address indexed to, uint256 amount);

    // ──────────────────────────────────────────────
    //  Constants & Immutables
    // ──────────────────────────────────────────────
    uint256 public constant MAX_SUPPLY = 100_000_000 * 1e18; // 100M tokens
    address public immutable governance;

    // ──────────────────────────────────────────────
    //  Modifiers
    // ──────────────────────────────────────────────
    modifier onlyGovernance() {
        if (msg.sender != governance) revert UnauthorizedGovernance();
        _;
    }

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────
    constructor(address _governance)
        ERC20("HELAL Token", "HELAL")
        ERC20Permit("HELAL Token")
    {
        governance = _governance;
        _mint(_governance, 10_000_000 * 1e18); // 10M initial supply
    }

    // ──────────────────────────────────────────────
    //  External Functions
    // ──────────────────────────────────────────────

    /// @notice Mints new HELAL tokens — restricted to governance
    /// @param to     Recipient address
    /// @param amount Amount of tokens to mint (in wei)
    function mint(address to, uint256 amount) external onlyGovernance {
        if (totalSupply() + amount > MAX_SUPPLY) revert MaxSupplyExceeded();
        _mint(to, amount);
        emit GovernanceMint(to, amount);
    }

    /// @notice Burns tokens from the caller's balance
    /// @param amount Amount of tokens to burn (in wei)
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
