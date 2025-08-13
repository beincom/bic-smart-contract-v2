// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {MiniGamePointShop} from "../../src/distribute/MiniGamePointShop.sol";

/**
 * @title DeployMiniGamePointShop
 * @notice Script to deploy the MiniGamePointShop contract
 */
contract DeployMiniGamePointShop is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address verifier = vm.envAddress("VERIFIER_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        MiniGamePointShop pointShop = new MiniGamePointShop(deployer, verifier);
        
        vm.stopBroadcast();
        
        console.log("MiniGamePointShop deployed at:", address(pointShop));
        console.log("Owner:", deployer);
        console.log("Verifier:", verifier);
    }
}
