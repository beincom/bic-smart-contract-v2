// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TieredStakingPool} from "../src/staking/TieredStakingPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingDeployScript is Script {
    struct TierConfig {
        uint256 maxTokens;
        uint256 annualInterestRate;
        uint256 lockDuration;
    }

    uint256 public monToSec = 30 days;
    uint256 public milToken = 1e24;

    TierConfig[] public duration_6 = [
        TierConfig(5 * milToken, 3500, 6 * monToSec),
        TierConfig(10 * milToken, 3000, 6 * monToSec),
        TierConfig(15 * milToken, 2500, 6 * monToSec),
        TierConfig(20 * milToken, 2000, 6 * monToSec),
        TierConfig(25 * milToken, 1500, 6 * monToSec),
        TierConfig(30 * milToken, 1000, 6 * monToSec),
        TierConfig(35 * milToken, 500, 6 * monToSec)
    ];
    TierConfig[] public duration_9 = [
        TierConfig(5 * milToken, 3000 * 4 / 3, 9 * monToSec),
        TierConfig(10 * milToken, 2625 * 4 / 3, 9 * monToSec),
        TierConfig(15 * milToken, 2250 * 4 / 3, 9 * monToSec),
        TierConfig(20 * milToken, 1875 * 4 / 3, 9 * monToSec),
        TierConfig(25 * milToken, 1500 * 4 / 3, 9 * monToSec),
        TierConfig(30 * milToken, 1125 * 4 / 3, 9 * monToSec),
        TierConfig(35 * milToken, 750 * 4 / 3, 9 * monToSec),
        TierConfig(40 * milToken, 375 * 4 / 3, 9 * monToSec)
    ];
    TierConfig[] public duration_12 = [
        TierConfig(5 * milToken, 4500, 12 * monToSec),
        TierConfig(10 * milToken, 4000, 12 * monToSec),
        TierConfig(15 * milToken, 3500, 12 * monToSec),
        TierConfig(20 * milToken, 3000, 12 * monToSec),
        TierConfig(25 * milToken, 2500, 12 * monToSec),
        TierConfig(30 * milToken, 2000, 12 * monToSec),
        TierConfig(35 * milToken, 1500, 12 * monToSec),
        TierConfig(40 * milToken, 1000, 12 * monToSec),
        TierConfig(45 * milToken, 500, 12 * monToSec)
    ];
    TierConfig[] public duration_15 = [
        TierConfig(5 * milToken, 6250 * 4 / 5, 15 * monToSec),
        TierConfig(10 * milToken, 5625 * 4 / 5, 15 * monToSec),
        TierConfig(15 * milToken, 5000 * 4 / 5, 15 * monToSec),
        TierConfig(20 * milToken, 4375 * 4 / 5, 15 * monToSec),
        TierConfig(25 * milToken, 3750 * 4 / 5, 15 * monToSec),
        TierConfig(30 * milToken, 3125 * 4 / 5, 15 * monToSec),
        TierConfig(35 * milToken, 2500 * 4 / 5, 15 * monToSec),
        TierConfig(40 * milToken, 1875 * 4 / 5, 15 * monToSec),
        TierConfig(45 * milToken, 1250 * 4 / 5, 15 * monToSec),
        TierConfig(50 * milToken, 625 * 4 / 5, 15 * monToSec)
    ];

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // deploy tiers in duration 6 month
        deploy_tierStaking(duration_6);
        // deploy tiers in duration 9 month
        deploy_tierStaking(duration_9);
        // deploy tiers in duration 12 month
        deploy_tierStaking(duration_12);
        // deploy tiers in duration 15 month
        deploy_tierStaking(duration_15);

        vm.stopBroadcast();
    }

    function deploy_tierStaking(TierConfig[] memory tiers) internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address stakingToken = vm.envAddress("STAKING_TOKEN");
        address stakingOwner = vm.envAddress("STAKING_OWNER");
        TieredStakingPool tieredStakingPool = new TieredStakingPool(IERC20(stakingToken), deployer);
        console.log("Tiered Staking Pool deployed at:", address(tieredStakingPool));
        
        uint256 tiersLength = tiers.length;
        uint256[] memory maxTokens = new uint256[](tiersLength);
        uint256[] memory annualInterestRates = new uint256[](tiersLength);
        uint256[] memory lockDurations = new uint256[](tiersLength);
        
        for (uint256 i = 0; i < tiersLength; i++) {
            maxTokens[i] = tiers[i].maxTokens;
            annualInterestRates[i] = tiers[i].annualInterestRate;
            lockDurations[i] = tiers[i].lockDuration;
        }

        tieredStakingPool.addBatchTier(
            maxTokens,
            annualInterestRates,
            lockDurations
        );

        for (uint256 i = 0; i < tiersLength; i++) {
            (uint256 maxToken, uint256 apr, uint256 lockDuration,) = tieredStakingPool.tiers(i);
            require(maxToken == tiers[i].maxTokens);
            require(apr == tiers[i].annualInterestRate);
            require(lockDuration == tiers[i].lockDuration);
        }

        tieredStakingPool.transferOwnership(stakingOwner);
    }
}