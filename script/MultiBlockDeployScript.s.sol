// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BicMultiBlock} from "../src/utils/MultiBlock.sol";
import {BicTokenPaymaster} from "../src/BicTokenPaymaster.sol";

contract MultiBlockDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address multiBlockOwner = vm.envAddress("MULTI_BLOCK_OWNER");
        address bic = vm.envAddress("MULTI_BLOCK_BIC_ADDRESS");
        vm.startBroadcast(deployerPrivateKey);
        BicMultiBlock multiBlock = new BicMultiBlock(multiBlockOwner, bic);
        console.log("Bic Token Paymaster deployed contract:", address(multiBlock));
        vm.stopBroadcast();
    }
}
