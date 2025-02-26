// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TieredStakingPool} from "../src/staking/TieredStakingPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address stakingToken = vm.envAddress("STAKING_TOKEN");
        address stakingOwner = vm.envAddress("STAKING_OWNER");
        vm.startBroadcast(deployerPrivateKey);

        TieredStakingPool tieredStakingPool = new TieredStakingPool(IERC20(stakingToken), stakingOwner);
        console.log("Tiered Staking Pool deployed at:", address(tieredStakingPool));

        vm.stopBroadcast();
    }
}