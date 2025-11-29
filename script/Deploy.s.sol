// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/InnChain.sol";

contract DeployScript is Script {
    function run() external {
        // Load private key dari environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Lisk Sepolia USDT address (ganti kalau pake token lain)
        // Kalau belum ada, deploy MockUSDC dulu
        address stablecoinAddress = vm.envAddress("STABLECOIN_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy InnChain contract
        InnChain innchain = new InnChain(stablecoinAddress);
        
        console.log("InnChain deployed to:", address(innchain));
        console.log("Stablecoin used:", stablecoinAddress);
        console.log("Hotel count:", innchain.hotelCount());
        console.log("Room class count:", innchain.roomClassCount());
        
        vm.stopBroadcast();
    }
}