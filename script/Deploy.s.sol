// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
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

/// @title Deploy — Full Mainnet Deployment
/// @author Abdulwahed Mansour — Sunna Protocol
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address stablecoin = vm.envAddress("STABLECOIN_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Layer 1: Core
        SolvencyGuard solvencyGuard = new SolvencyGuard(deployer);
        ShariaGuard shariaGuard = new ShariaGuard(deployer);
        FeeController feeController = new FeeController(address(solvencyGuard), deployer);
        ConstitutionalGuard constitutionalGuard = new ConstitutionalGuard(deployer);
        
        // Layer 3: Mudaraba
        MudarabaEngine engine = new MudarabaEngine(stablecoin);
        SunnaLedger ledger = new SunnaLedger();
        SunnaVault vault = new SunnaVault(stablecoin);
        SunnaShares shares = new SunnaShares("Sunna Shares", "sSHR", address(vault));
        OracleValidator oracle = new OracleValidator();
        
        // Layer 1: TakafulBuffer (needs solvency guard)
        TakafulBuffer buffer = new TakafulBuffer(address(solvencyGuard), stablecoin, deployer);
        
        // Layer 2: Shield
        SunnaShield shield = new SunnaShield(
            IERC20(stablecoin),
            "Sunna Shield",
            "sSHD",
            deployer,
            500
        );
        
        // Layer 4: Governance
        HELALToken helal = new HELALToken(deployer);
        
        // Configure permissions
        ledger.setAuthorizedRecorder(address(engine), true);
        
        vm.stopBroadcast();
        
        // Log deployed addresses
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
