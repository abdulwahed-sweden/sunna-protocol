// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SolvencyGuard} from "./SolvencyGuard.sol";

/// @title TakafulBuffer — Fee Escrow Until Solvency Verification
/// @author Abdulwahed Mansour — Sunna Protocol
/// @notice Holds protocol fees in escrow until SolvencyGuard confirms system solvency
/// @dev Fees are only released when the system is solvent; forfeited on insolvency
contract TakafulBuffer {
    using SafeERC20 for IERC20;

    error InsolvencyDetected();
    error NoEscrowedFees();
    error UnauthorizedCaller();

    event FeeEscrowed(address recipient, uint256 amount);
    event FeeReleased(address recipient, uint256 amount);
    event FeeForfeited(address recipient, uint256 amount);

    SolvencyGuard public immutable solvencyGuard;
    IERC20 public immutable token;
    address public immutable admin;

    mapping(address => uint256) public escrowedFees;

    modifier onlyAdmin() {
        if (msg.sender != admin) revert UnauthorizedCaller();
        _;
    }

    constructor(address _solvencyGuard, address _token, address _admin) {
        solvencyGuard = SolvencyGuard(_solvencyGuard);
        token = IERC20(_token);
        admin = _admin;
    }

    /// @notice Escrow fees for a recipient — only callable by admin
    /// @param recipient The address that will receive fees upon release
    /// @param amount The amount of tokens to escrow
    function escrowFee(address recipient, uint256 amount) external onlyAdmin {
        token.safeTransferFrom(msg.sender, address(this), amount);
        escrowedFees[recipient] += amount;
        emit FeeEscrowed(recipient, amount);
    }

    /// @notice Release escrowed fees to a recipient — only if system is solvent
    /// @param recipient The address to release fees to
    function releaseFees(address recipient) external {
        if (!solvencyGuard.checkSolvency()) revert InsolvencyDetected();
        uint256 amount = escrowedFees[recipient];
        if (amount == 0) revert NoEscrowedFees();
        escrowedFees[recipient] = 0;
        token.safeTransfer(recipient, amount);
        emit FeeReleased(recipient, amount);
    }

    /// @notice Forfeit escrowed fees — only callable by admin (used on insolvency)
    /// @param recipient The address whose escrowed fees are forfeited
    function forfeitFees(address recipient) external onlyAdmin {
        uint256 amount = escrowedFees[recipient];
        if (amount == 0) revert NoEscrowedFees();
        escrowedFees[recipient] = 0;
        emit FeeForfeited(recipient, amount);
    }
}
