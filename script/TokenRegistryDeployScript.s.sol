// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TokenRegistry} from "../src/utils/TokenRegistry.sol";

contract TokenRegistryDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address usdt = vm.envAddress("USDT_ADDRESS");
        address deployOwner = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        TokenRegistry tokenRegistry = new TokenRegistry(deployOwner);
        tokenRegistry.registerERC20(usdt, block.timestamp);
        vm.stopBroadcast();
    }
}


