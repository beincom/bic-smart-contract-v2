// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Erc20TransferMessage} from "../src/donation/Erc20TransferMessage.sol";
import {BICVesting} from "../src/vest/BICVesting.sol";

contract Erc20MessageEmitterScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Erc20TransferMessage erc20MessageEmitter = new Erc20TransferMessage(operator);
        console.log("Erc20TransferMessage deployed at:", address(erc20MessageEmitter));
        erc20MessageEmitter.setFeeBps(600);
        erc20MessageEmitter.setTreasury(address(0x52cEA6663515882904d5D326dDFC272EB39134d9));
        erc20MessageEmitter.transferOwnership(address(0x52cEA6663515882904d5D326dDFC272EB39134d9));
        vm.stopBroadcast();
    }
}