// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../src/BicTokenPaymaster.sol";
import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {console} from "forge-std/console.sol";

contract BicDeployer is Script {
    address entrypoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    address owner = 0xeaBcd21B75349c59a4177E10ed17FBf2955fE697;
    address[] signers = [0xeaBcd21B75349c59a4177E10ed17FBf2955fE697];
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address proxy = Upgrades.deployUUPSProxy(
            "BicTokenPaymaster.sol",
            abi.encodeCall(
                BicTokenPaymaster.initialize,
                (
                    entrypoint,
                    owner,
                    signers
                )
            )
        );
        console.log("BicTokenPaymaster deployed at:", proxy);
        vm.stopBroadcast();
    }
}