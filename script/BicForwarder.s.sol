// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BicForwarder} from "../src/utils/BicForwarder.sol";

contract DeployBicForwarderScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address forwarderOwner = vm.envAddress("FORWARDER_OWNER_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        BicForwarder forwarder = new BicForwarder(forwarderOwner);
        console.log("BicForwarder deployed at:", address(forwarder));


        vm.stopBroadcast();
    }
}


contract AddControllerScript is Script {
    BicForwarder forwarder = BicForwarder(0xc4C47b7539F7876485b96DE6970c602050810Ca5);
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address controllerAddress = address(0x134231A5F66637625c90D65a3bc5Be187BB94466);

        vm.startBroadcast(deployerPrivateKey);
        forwarder.addController(controllerAddress);


        vm.stopBroadcast();
    }
}