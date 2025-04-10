// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BicTokenPaymaster} from "../src/BicTokenPaymaster.sol";

contract BicDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address entrypoint = vm.envAddress("SMART_ACCOUNT_ENTRY_POINT");
        address superController = vm.envAddress("BIC_SUPPER_CONTROLLER");
        address[] memory offchainVerifiers = new address[](1);
        offchainVerifiers[0] = vm.envAddress("BIC_OFF_CHAIN_VERIFIER");
        vm.startBroadcast(deployerPrivateKey);
        BicTokenPaymaster bic = new BicTokenPaymaster(entrypoint, superController, offchainVerifiers);
        console.log("Bic Token Paymaster deployed contract:", address (bic));

        vm.stopBroadcast();
    }
}
