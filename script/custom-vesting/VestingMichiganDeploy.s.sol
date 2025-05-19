// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BICVesting} from "../../src/vest/BICVesting.sol";


contract SampleBicFactory {
    function deployProxyByImplementation(
        address _implementation,
        bytes memory _data,
        bytes32 _salt
    ) public returns (address deployedProxy) {
        // Deploy the proxy
    }
}

contract VestingMichiganDeployScript  is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address bicFactoryAddress = vm.envAddress("BIC_FACTORY_ADDRESS");
        address vesting = vm.envAddress("VESTING_ADDRESS");
        address bic = vm.envAddress("BIC_ADDRESS");


        uint256 totalAmount = 20_000 * 1e18;
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = 0xfE81Db5C18541c4f117A67215D05Ba0F44768d2E;

        uint16[] memory allocations = new uint16[](1);
        allocations[0] = 10_000;
        uint64 startTime = 1747785600; // Wednesday, May 21, 2025 12:00:00 AM GMT+00:00 DST
        uint64 durationSeconds = 30 days;
        uint64 redeemRate = 3334; // 1/3

        SampleBicFactory bicFactory = SampleBicFactory(bicFactoryAddress);
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,uint256,address[],uint16[],uint64,uint64,uint64)",
            bic,
            totalAmount,
            beneficiaries,
            allocations,
            startTime,
            durationSeconds,
            redeemRate
        );

        vm.startBroadcast(deployerPrivateKey);
        address clone = bicFactory.deployProxyByImplementation(
            address(vesting),
            initData,
            bytes32(0)
        );
        vm.stopBroadcast();
        console.log("BICVesting deployed at:", address(clone));
    }
}
