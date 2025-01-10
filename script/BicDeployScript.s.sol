// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BicTokenPaymaster} from "../src/BicTokenPaymaster.sol";

contract BicDeployScript is Script {
    address entrypoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    address superController = 0xeaBcd21B75349c59a4177E10ed17FBf2955fE697;
    address[] signers = [0xeaBcd21B75349c59a4177E10ed17FBf2955fE697];

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        BicTokenPaymaster bic = new BicTokenPaymaster(entrypoint, superController, signers);
        console.log("Bic Token Paymaster deployed contract:", address (bic));

        vm.stopBroadcast();
    }
}
