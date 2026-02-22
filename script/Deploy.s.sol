// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/core/SolvencyGuard.sol";
import "../src/core/FeeController.sol";
import "../src/core/ShariaGuard.sol";
import "../src/core/TakafulBuffer.sol";
import "../src/core/ConstitutionalGuard.sol";
import "../src/mudaraba/MudarabaEngine.sol";
import "../src/mudaraba/SunnaLedger.sol";
import "../src/mudaraba/OracleValidator.sol";
import "../src/governance/HELALToken.sol";

/// @title Deploy — Sunna Protocol Full Deployment
/// @author Abdulwahed Mansour — Sunna Protocol
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address stablecoin = vm.envAddress("STABLECOIN_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Layer 1: Sunna Core
        SolvencyGuard solvencyGuard = new SolvencyGuard();
        FeeController feeController = new FeeController(address(solvencyGuard), 500);
        ShariaGuard shariaGuard = new ShariaGuard();
        TakafulBuffer takafulBuffer = new TakafulBuffer(stablecoin, address(solvencyGuard));
        ConstitutionalGuard constitutionalGuard = new ConstitutionalGuard(address(solvencyGuard));

        // Layer 3: Sunna Mudaraba
        MudarabaEngine mudarabaEngine = new MudarabaEngine(stablecoin);
        SunnaLedger sunnaLedger = new SunnaLedger();
        OracleValidator oracleValidator = new OracleValidator(3600);

        // Layer 4: Governance
        HELALToken helalToken = new HELALToken(deployer);

        // Authorization
        solvencyGuard.authorizeEngine(address(mudarabaEngine));
        takafulBuffer.authorizeEngine(address(mudarabaEngine));
        sunnaLedger.setAuthorizedRecorder(address(mudarabaEngine), true);

        // Whitelist stablecoin
        shariaGuard.whitelistAsset(stablecoin, "Primary stablecoin for Mudaraba operations");

        vm.stopBroadcast();

        // Log deployed addresses
        console.log("=== Sunna Protocol Deployed ===");
        console.log("SolvencyGuard:", address(solvencyGuard));
        console.log("FeeController:", address(feeController));
        console.log("ShariaGuard:", address(shariaGuard));
        console.log("TakafulBuffer:", address(takafulBuffer));
        console.log("ConstitutionalGuard:", address(constitutionalGuard));
        console.log("MudarabaEngine:", address(mudarabaEngine));
        console.log("SunnaLedger:", address(sunnaLedger));
        console.log("OracleValidator:", address(oracleValidator));
        console.log("HELALToken:", address(helalToken));
    }
}
