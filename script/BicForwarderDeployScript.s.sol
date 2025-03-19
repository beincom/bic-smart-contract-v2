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

