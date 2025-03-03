// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TieredStakingPool} from "../src/staking/TieredStakingPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TierdStakingPoolDeployScript is Script {
    address token = 0x1E3e1F2f400E72AE9944F906177E39c252348Fe4;
    address superController = 0xeaBcd21B75349c59a4177E10ed17FBf2955fE697;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        TieredStakingPool stakingPool = new TieredStakingPool(IERC20(token), superController);
        console.log("TieredStakingPool deployed contract:", address (stakingPool));

        vm.stopBroadcast();
    }
}
