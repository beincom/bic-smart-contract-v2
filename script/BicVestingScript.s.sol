// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BICVestingFactory} from "../src/vest/BICVestingFactory.sol";
import {BICVesting} from "../src/vest/BICVesting.sol";

contract BicVestingScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address operator = vm.envAddress("REDEMPTION_OPERATOR_ADDRESS");
        vm.startBroadcast(deployerPrivateKey);

        BICVestingFactory vestingFactory = new BICVestingFactory(operator);
        console.log("BICVestingFactory deployed at:", address(vestingFactory));

        vm.stopBroadcast();
    }
}

contract CreateVestingScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        BICVestingFactory vestingFactory = BICVestingFactory(0xeC3Bf579b83Bd7141147df786E1F7354EC2e9F8A);
        uint256 totalAmount = 1111 * 1e18;
        address erc20 = 0x03c36763E271211961e9E42DC6D600F9cF0Ea417;
        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = 0x97275c14bE84fc5F541516E6c7aE7A9F0a7eBeeA;
        beneficiaries[1] = 0x74F54227B6C8D6B95D2220c83332d84Fe646d3d0;

        uint16[] memory allocations = new uint16[](2);
        allocations[0] = 2000;
        allocations[1] = 8000;
        uint64 durationSeconds = 5 minutes;
        uint64 redeemRate = 300;
        vm.startBroadcast(deployerPrivateKey);

        BICVesting vesting = vestingFactory.createRedeem(erc20, totalAmount, beneficiaries, allocations, durationSeconds, redeemRate);
        console.log("BICVesting deployed at:", address(vesting));

        vm.stopBroadcast();
    }
}