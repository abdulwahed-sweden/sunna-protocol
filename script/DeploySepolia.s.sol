// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/core/SolvencyGuard.sol";
import "../src/core/ShariaGuard.sol";
import "../src/core/TakafulBuffer.sol";
import "../src/core/FeeController.sol";
import "../src/core/ConstitutionalGuard.sol";
import "../src/shield/SunnaShield.sol";
import "../src/mudaraba/MudarabaEngine.sol";
import "../src/mudaraba/SunnaLedger.sol";
import "../src/mudaraba/SunnaVault.sol";
import "../src/mudaraba/SunnaShares.sol";
import "../src/mudaraba/OracleValidator.sol";
import "../src/governance/HELALToken.sol";

/// @title MockStablecoin — Test stablecoin for Sepolia
contract MockStablecoin is ERC20 {
    constructor() ERC20("Mock USDT", "mUSDT") {
        _mint(msg.sender, 1_000_000 * 1e18);
    }
}

/// @title DeploySepolia — Testnet Deployment
/// @author Abdulwahed Mansour — Sunna Protocol
contract DeploySepolia is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock stablecoin for testnet
        MockStablecoin stablecoin = new MockStablecoin();

        // Layer 1: Core
        SolvencyGuard solvencyGuard = new SolvencyGuard();
        ShariaGuard shariaGuard = new ShariaGuard();
        FeeController feeController = new FeeController(address(solvencyGuard), 500);
        TakafulBuffer buffer = new TakafulBuffer(address(stablecoin), address(solvencyGuard));
        ConstitutionalGuard constitutionalGuard = new ConstitutionalGuard(address(solvencyGuard));

        // Layer 3: Mudaraba
        MudarabaEngine engine = new MudarabaEngine(address(stablecoin));
        SunnaLedger ledger = new SunnaLedger();
        SunnaVault vault = new SunnaVault(address(stablecoin), address(solvencyGuard), address(shariaGuard));
        SunnaShares shares = new SunnaShares("Sunna Shares", "sSHR", address(vault), true);
        OracleValidator oracle = new OracleValidator(3600);

        // Layer 2: Shield
        SunnaShield shield = new SunnaShield(
            IERC20(address(stablecoin)),
            "Sunna Shield",
            "sSHD",
            deployer,
            500
        );

        // Layer 4: Governance
        HELALToken helal = new HELALToken(deployer);

        // Configure
        solvencyGuard.authorizeEngine(address(engine));
        buffer.authorizeEngine(address(engine));
        ledger.setAuthorizedRecorder(address(engine), true);
        shariaGuard.whitelistAsset(address(stablecoin), "Testnet mock stablecoin");

        vm.stopBroadcast();

        console.log("=== Sepolia Deployment ===");
        console.log("MockStablecoin:", address(stablecoin));
        console.log("SolvencyGuard:", address(solvencyGuard));
        console.log("ShariaGuard:", address(shariaGuard));
        console.log("FeeController:", address(feeController));
        console.log("ConstitutionalGuard:", address(constitutionalGuard));
        console.log("TakafulBuffer:", address(buffer));
        console.log("SunnaShield:", address(shield));
        console.log("MudarabaEngine:", address(engine));
        console.log("SunnaLedger:", address(ledger));
        console.log("SunnaVault:", address(vault));
        console.log("SunnaShares:", address(shares));
        console.log("OracleValidator:", address(oracle));
        console.log("HELALToken:", address(helal));
    }
}
