// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SunnaVault — Capital Custody Vault
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Holds USDT/USDC deposits for Mudaraba capital allocation
contract SunnaVault is ReentrancyGuard {

    error InsufficientBalance();
    error UnauthorizedAdmin();

    event Deposited(address indexed depositor, uint256 amount);
    event Withdrawn(address indexed depositor, uint256 amount);
    event Allocated(address indexed to, uint256 amount);

    IERC20 public immutable stablecoin;
    address public immutable admin;
    uint256 public totalDeposits;
    mapping(address => uint256) public deposits;

    constructor(address _stablecoin) {
        stablecoin = IERC20(_stablecoin);
        admin = msg.sender;
    }

    /// @notice Deposit stablecoins into the vault
    function deposit(uint256 amount) external nonReentrant {
        SafeERC20.safeTransferFrom(stablecoin, msg.sender, address(this), amount);
        deposits[msg.sender] += amount;
        totalDeposits += amount;
        emit Deposited(msg.sender, amount);
    }

    /// @notice Withdraw stablecoins from the vault
    function withdraw(uint256 amount) external nonReentrant {
        if (deposits[msg.sender] < amount) revert InsufficientBalance();
        deposits[msg.sender] -= amount;
        totalDeposits -= amount;
        SafeERC20.safeTransfer(stablecoin, msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Allocate capital to a project (admin only)
    function allocateToProject(address to, uint256 amount) external {
        if (msg.sender != admin) revert UnauthorizedAdmin();
        SafeERC20.safeTransfer(stablecoin, to, amount);
        emit Allocated(to, amount);
    }
}
