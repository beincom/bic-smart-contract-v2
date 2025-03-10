// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TokenRegistry} from "../src/utils/TokenRegistry.sol";
import {BICVesting} from "../src/vest/BICVesting.sol";

contract Erc20MessageEmitterScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        TokenRegistry tokenRegistry = new TokenRegistry(operator);
        console.log("TokenRegistry deployed at:", address(tokenRegistry));
        vm.stopBroadcast();
    }
}