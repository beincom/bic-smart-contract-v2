// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BicTokenPaymaster} from "../src/BicTokenPaymaster.sol";

contract BicDeployScript is Script {
    address entrypoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    address superController = 0xaCc34513D10bd5c57109bF83A8754856FF0b0eb0;
    address[] signers = [0xaCc34513D10bd5c57109bF83A8754856FF0b0eb0];

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        BicTokenPaymaster bic = new BicTokenPaymaster(entrypoint, superController, signers);
        console.log("Bic Token Paymaster deployed contract:", address (bic));

        vm.stopBroadcast();
    }
}
