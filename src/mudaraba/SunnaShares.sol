// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title SunnaShares — Dynamic Investment Shares
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice ERC-20 token representing investment shares in Mudaraba projects
contract SunnaShares is ERC20 {

    error UnauthorizedVault();

    address public immutable vault;

    modifier onlyVault() {
        if (msg.sender != vault) revert UnauthorizedVault();
        _;
    }

    constructor(string memory name, string memory symbol, address _vault) ERC20(name, symbol) {
        vault = _vault;
    }

    /// @notice Mint shares to an investor
    function mint(address to, uint256 amount) external onlyVault {
        _mint(to, amount);
    }

    /// @notice Burn shares from an investor
    function burn(address from, uint256 amount) external onlyVault {
        _burn(from, amount);
    }
}
