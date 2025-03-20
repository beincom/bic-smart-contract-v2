// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BicForwarder} from "../src/forwarder/BicForwarder.sol";

contract BicForwarderDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployOwner = vm.addr(deployerPrivateKey);
        address afterDeployOwner = vm.envAddress("AFTER_DEPLOY_OWNER");
        vm.startBroadcast(deployerPrivateKey);
        BicForwarder bicForwarder = new BicForwarder(deployOwner);
        // bicForwarder.transferOwnership(afterDeployOwner);
        vm.stopBroadcast();
    }
}

contract AddControllerScript is Script {
    BicForwarder forwarder = BicForwarder(0x73cc7bD89065028C700aA6b3102089938dCAbcd5);
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address controllerAddress = address(0x5Be1D7b5552c39c0fd25C1C5cd9DfF0b094b9272);

        vm.startBroadcast(deployerPrivateKey);
        forwarder.addController(controllerAddress);


        vm.stopBroadcast();
    }
}

