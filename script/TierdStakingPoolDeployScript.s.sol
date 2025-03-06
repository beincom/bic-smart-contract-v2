// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TieredStakingPool} from "../src/staking/TieredStakingPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TierdStakingPoolDeployScript is Script {
    address token = 0xB1C3960aeeAf4C255A877da04b06487BBa698386;
    address superController = 0xb99f671B24B8E1dA7a67EfbdB0B627BEF9068c65;

    struct AddTier {
        uint256 maxTokens;
        uint256 annualInterestRate;
        uint256 lockDuration;
    }

    AddTier[] tier_6months = [
        AddTier(10_000_000 ether, 3500, 182 days),
        AddTier(20_000_000 ether, 3000, 182 days), 
        AddTier(30_000_000 ether, 2500, 182 days),
        AddTier(40_000_000 ether, 2000, 182 days),
        AddTier(50_000_000 ether, 1500, 182 days),
        AddTier(60_000_000 ether, 1000, 182 days),
        AddTier(70_000_000 ether, 500, 182 days)
    ];

    AddTier[] tier_9months = [
        AddTier(10_000_000 ether, 4000, 273 days),
        AddTier(20_000_000 ether, 3500, 273 days),
        AddTier(30_000_000 ether, 3000, 273 days),
        AddTier(40_000_000 ether, 2500, 273 days),
        AddTier(50_000_000 ether, 2000, 273 days),
        AddTier(60_000_000 ether, 1500, 273 days),
        AddTier(70_000_000 ether, 1000, 273 days),
        AddTier(80_000_000 ether, 500, 273 days)
    ];

    AddTier[] tier_12months = [
        AddTier(10_000_000 ether, 4500, 365 days),
        AddTier(20_000_000 ether, 4000, 365 days),
        AddTier(30_000_000 ether, 3500, 365 days),
        AddTier(40_000_000 ether, 3000, 365 days),
        AddTier(50_000_000 ether, 2500, 365 days),
        AddTier(60_000_000 ether, 2000, 365 days),
        AddTier(70_000_000 ether, 1500, 365 days),
        AddTier(80_000_000 ether, 1000, 365 days),
        AddTier(90_000_000 ether, 500, 365 days)
    ];

    AddTier[] tier_15months = [
        AddTier(10_000_000 ether, 5000, 456 days),
        AddTier(20_000_000 ether, 4500, 456 days),
        AddTier(30_000_000 ether, 4000, 456 days),
        AddTier(40_000_000 ether, 3500, 456 days),
        AddTier(50_000_000 ether, 3000, 456 days),
        AddTier(60_000_000 ether, 2500, 456 days),
        AddTier(70_000_000 ether, 2000, 456 days),
        AddTier(80_000_000 ether, 1500, 456 days),
        AddTier(90_000_000 ether, 1000, 456 days),
        AddTier(100_000_000 ether, 500, 456 days)
    ];

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        console.log("Deployer address:", vm.addr(deployerPrivateKey));
        vm.startBroadcast(deployerPrivateKey);
        // Deploy 6 months tier pool
        TieredStakingPool stakingPool6Months = new TieredStakingPool(IERC20(token), vm.addr(deployerPrivateKey));
        console.log("TieredStakingPool 6 months deployed contract:", address(stakingPool6Months));
        for (uint256 i = 0; i < tier_6months.length; i++) {
            stakingPool6Months.addTier(tier_6months[i].maxTokens, tier_6months[i].annualInterestRate, tier_6months[i].lockDuration);
        }

        // Deploy 9 months tier pool
        TieredStakingPool stakingPool9Months = new TieredStakingPool(IERC20(token), vm.addr(deployerPrivateKey));
        console.log("TieredStakingPool 9 months deployed contract:", address(stakingPool9Months));
        for (uint256 i = 0; i < tier_9months.length; i++) {
            stakingPool9Months.addTier(tier_9months[i].maxTokens, tier_9months[i].annualInterestRate, tier_9months[i].lockDuration);
        }

        // Deploy 12 months tier pool
        TieredStakingPool stakingPool12Months = new TieredStakingPool(IERC20(token), vm.addr(deployerPrivateKey));
        console.log("TieredStakingPool 12 months deployed contract:", address(stakingPool12Months));
        for (uint256 i = 0; i < tier_12months.length; i++) {
            stakingPool12Months.addTier(tier_12months[i].maxTokens, tier_12months[i].annualInterestRate, tier_12months[i].lockDuration);
        }

        // Deploy 15 months tier pool
        TieredStakingPool stakingPool15Months = new TieredStakingPool(IERC20(token), vm.addr(deployerPrivateKey));
        console.log("TieredStakingPool 15 months deployed contract:", address(stakingPool15Months));
        for (uint256 i = 0; i < tier_15months.length; i++) {
            stakingPool15Months.addTier(tier_15months[i].maxTokens, tier_15months[i].annualInterestRate, tier_15months[i].lockDuration);
        }

        // Transfer ownership to super controller
        stakingPool6Months.transferOwnership(superController);
        stakingPool9Months.transferOwnership(superController);
        stakingPool12Months.transferOwnership(superController);
        stakingPool15Months.transferOwnership(superController);

        vm.stopBroadcast();
    }
}
