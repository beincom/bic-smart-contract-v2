// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {BicTokenPaymaster} from "../src/BicTokenPaymaster.sol";

contract BicDeployScript is Script {
    address entrypoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    address superController = 0xaCc34513D10bd5c57109bF83A8754856FF0b0eb0;
    address[] signers = [0xaCc34513D10bd5c57109bF83A8754856FF0b0eb0];

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address proxy = Upgrades.deployUUPSProxy(
            "BicTokenPaymaster.sol",
            abi.encodeCall(
                BicTokenPaymaster.initialize,
                (entrypoint, superController, signers)
            )
        );

        console.log("Bic Token Paymaster deployed contract:", proxy);

        vm.stopBroadcast();
    }
}
