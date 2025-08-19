// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import "../../src/distribute/MiniGamePoolReward.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract MiniGamePoolRewardDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
        address owner = vm.envAddress("AFTER_DEPLOY_OWNER");
        vm.startBroadcast(deployerPrivateKey);
        MiniGamePoolReward rewardContract = new MiniGamePoolReward(owner);
        console.log("MiniGamePoolReward deployed at:", address(rewardContract));
        vm.stopBroadcast();
    }
}