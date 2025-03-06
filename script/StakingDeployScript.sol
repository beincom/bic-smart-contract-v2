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

    TierConfig[] public duration_6;
    TierConfig[] public duration_9;
    TierConfig[] public duration_12;
    TierConfig[] public duration_15;

    uint256 public monToSec = 30;


    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // deploy tiers in duration 6 month
        config_duration6();
        deploy_tierStaking(duration_6);
        // deploy tiers in duration 9 month
        config_duration9();
        deploy_tierStaking(duration_9);
        // deploy tiers in duration 12 month
        config_duration12();
        deploy_tierStaking(duration_12);
        // deploy tiers in duration 15 month
        config_duration15();
        deploy_tierStaking(duration_15);

        vm.stopBroadcast();
    }

    // add tier config for duration 6 month
    function config_duration6() internal {
        // tier 1
        duration_6.push(
            TierConfig({
                maxTokens: 10e24,
                annualInterestRate: 3500,
                lockDuration: 6 * monToSec
            })
        );
        // tier 2
        duration_6.push(
            TierConfig({
                maxTokens: 20e24,
                annualInterestRate: 3000,
                lockDuration: 6 * monToSec
            })
        );
        // tier 3
        duration_6.push(
            TierConfig({
                maxTokens: 30e24,
                annualInterestRate: 2500,
                lockDuration: 6 * monToSec
            })
        );
        // tier 4
        duration_6.push(
            TierConfig({
                maxTokens: 40e24,
                annualInterestRate: 2000,
                lockDuration: 6 * monToSec
            })
        );
        // tier 5
        duration_6.push(
            TierConfig({
                maxTokens: 50e24,
                annualInterestRate: 1500,
                lockDuration: 6 * monToSec
            })
        );
        // tier 6
        duration_6.push(
            TierConfig({
                maxTokens: 60e24,
                annualInterestRate: 1000,
                lockDuration: 6 * monToSec
            })
        );
        // tier 7
        duration_6.push(
            TierConfig({
                maxTokens: 70e24,
                annualInterestRate: 500,
                lockDuration: 6 * monToSec
            })
        );
    }

    // add tier config for duration 9 month
    function config_duration9() internal {
        // tier 1
        duration_9.push(
            TierConfig({
                maxTokens: 10e24,
                annualInterestRate: 3000 * 4 / 3,
                lockDuration: 9 * monToSec
            })
        );
        // tier 2
        duration_9.push(
            TierConfig({
                maxTokens: 20e24,
                annualInterestRate: 2625 * 4 / 3,
                lockDuration: 9 * monToSec
            })
        );
        // tier 3
        duration_9.push(
            TierConfig({
                maxTokens: 30e24,
                annualInterestRate: 2250 * 4 / 3,
                lockDuration: 9 * monToSec
            })
        );
        // tier 4
        duration_9.push(
            TierConfig({
                maxTokens: 40e24,
                annualInterestRate: 1875 * 4 / 3,
                lockDuration: 9 * monToSec
            })
        );
        // tier 5
        duration_9.push(
            TierConfig({
                maxTokens: 50e24,
                annualInterestRate: 1500 * 4 / 3,
                lockDuration: 9 * monToSec
            })
        );
        // tier 6
        duration_9.push(
            TierConfig({
                maxTokens: 60e24,
                annualInterestRate: 1125 * 4 / 3,
                lockDuration: 9 * monToSec
            })
        );
        // tier 7
        duration_9.push(
            TierConfig({
                maxTokens: 70e24,
                annualInterestRate: 750 * 4 / 3,
                lockDuration: 9 * monToSec
            })
        );
        // tier 8
        duration_9.push(
            TierConfig({
                maxTokens: 80e24,
                annualInterestRate: 375 * 4 / 3,
                lockDuration: 9 * monToSec
            })
        );
    }

    // add tier config for duration 12 month
    function config_duration12() internal {
        // tier 1
        duration_12.push(
            TierConfig({
                maxTokens: 10e24,
                annualInterestRate: 4500,
                lockDuration: 12 * monToSec
            })
        );
        // tier 2
        duration_12.push(
            TierConfig({
                maxTokens: 20e24,
                annualInterestRate: 4000,
                lockDuration: 12 * monToSec
            })
        );
        // tier 3
        duration_12.push(
            TierConfig({
                maxTokens: 30e24,
                annualInterestRate: 3500,
                lockDuration: 12 * monToSec
            })
        );
        // tier 4
        duration_12.push(
            TierConfig({
                maxTokens: 40e24,
                annualInterestRate: 3000,
                lockDuration: 12 * monToSec
            })
        );
        // tier 5
        duration_12.push(
            TierConfig({
                maxTokens: 50e24,
                annualInterestRate: 2500,
                lockDuration: 12 * monToSec
            })
        );
        // tier 6
        duration_12.push(
            TierConfig({
                maxTokens: 60e24,
                annualInterestRate: 2000,
                lockDuration: 12 * monToSec
            })
        );
        // tier 7
        duration_12.push(
            TierConfig({
                maxTokens: 70e24,
                annualInterestRate: 1500,
                lockDuration: 12 * monToSec
            })
        );
        // tier 8
        duration_12.push(
            TierConfig({
                maxTokens: 80e24,
                annualInterestRate: 1000,
                lockDuration: 12 * monToSec
            })
        );
        // tier 9
        duration_12.push(
            TierConfig({
                maxTokens: 90e24,
                annualInterestRate: 500,
                lockDuration: 12 * monToSec
            })
        );
    }

    // add tier config for duration 15 month
    function config_duration15() internal {
        // tier 1
        duration_15.push(
            TierConfig({
                maxTokens: 10e24,
                annualInterestRate: 6250 * 4 / 5,
                lockDuration: 15 * monToSec
            })
        );
        // tier 2
        duration_15.push(
            TierConfig({
                maxTokens: 20e24,
                annualInterestRate: 5625 * 4 / 5,
                lockDuration: 15 * monToSec
            })
        );
        // tier 3
        duration_15.push(
            TierConfig({
                maxTokens: 30e24,
                annualInterestRate: 5000 * 4 / 5,
                lockDuration: 15 * monToSec
            })
        );
        // tier 4
        duration_15.push(
            TierConfig({
                maxTokens: 40e24,
                annualInterestRate: 4375 * 4 / 5,
                lockDuration: 15 * monToSec
            })
        );
        // tier 5
        duration_15.push(
            TierConfig({
                maxTokens: 50e24,
                annualInterestRate: 3750 * 4 / 5,
                lockDuration: 15 * monToSec
            })
        );
        // tier 6
        duration_15.push(
            TierConfig({
                maxTokens: 60e24,
                annualInterestRate: 3125 * 4 / 5,
                lockDuration: 15 * monToSec
            })
        );
        // tier 7
        duration_15.push(
            TierConfig({
                maxTokens: 70e24,
                annualInterestRate: 2500 * 4 / 5,
                lockDuration: 15 * monToSec
            })
        );
        // tier 8
        duration_15.push(
            TierConfig({
                maxTokens: 80e24,
                annualInterestRate: 1875 * 4 / 5,
                lockDuration: 15 * monToSec
            })
        );
        // tier 9
        duration_15.push(
            TierConfig({
                maxTokens: 90e24,
                annualInterestRate: 1250 * 4 / 5,
                lockDuration: 15 * monToSec
            })
        );
        // tier 10
        duration_15.push(
            TierConfig({
                maxTokens: 100e24,
                annualInterestRate: 625 * 4 / 5,
                lockDuration: 15 * monToSec
            })
        );
    }

    function deploy_tierStaking(TierConfig[] memory tiers) internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address stakingToken = vm.envAddress("STAKING_TOKEN");
        address stakingOwner = vm.envAddress("STAKING_OWNER");
        TieredStakingPool tieredStakingPool = new TieredStakingPool(IERC20(stakingToken), deployer);
        console.log("Tiered Staking Pool deployed at:", address(tieredStakingPool));
        for (uint256 i = 0; i < tiers.length; i++) {
            tieredStakingPool.addTier(
                tiers[i].maxTokens,
                tiers[i].annualInterestRate,
                tiers[i].lockDuration
            );

            (uint256 maxTokens,,,) = tieredStakingPool.tiers(i);
            require(maxTokens == tiers[i].maxTokens);
        }
        tieredStakingPool.transferOwnership(stakingOwner);
    }
}