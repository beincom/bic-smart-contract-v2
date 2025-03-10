// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Erc20TransferMessage} from "../src/donation/Erc20TransferMessage.sol";
import {BICVesting} from "../src/vest/BICVesting.sol";

contract Erc20MessageEmitterScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address donationTreasury = vm.envAddress("DONATION_TREASURY");
        address donationOwner = vm.envAddress("DONATION_OWNER");
        vm.startBroadcast(deployerPrivateKey);

        Erc20TransferMessage erc20MessageEmitter = new Erc20TransferMessage(donationTreasury, donationOwner);
        console.log("Erc20TransferMessage deployed at:", address(erc20MessageEmitter));
        vm.stopBroadcast();
    }
}