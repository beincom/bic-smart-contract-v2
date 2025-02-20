// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {BicTokenPaymasterWithoutPreSetupExchange} from"./contracts/BicTokenPaymasterWithoutPreSetupExchange.sol";
import {TierStaking} from "../src/stake/TierStaking.sol";
import "forge-std/Test.sol";

contract TierStakingTest is Test {
    BicTokenPaymasterWithoutPreSetupExchange token;
    TierStaking tierStaking;
    address[] signers = [0xeaBcd21B75349c59a4177E10ed17FBf2955fE697];

    function setUp() public {

        token = new BicTokenPaymasterWithoutPreSetupExchange(
        0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
        address(this),
        signers
        );
        tierStaking = new TierStaking(address(token), address(this));
        uint8 tierIndex = 0;
        uint256 maxTokens = 5000 ether;
        uint256 annualInterestRate = 3_000;
        uint256 lockDuration = 30 days;
        tierStaking.setupTier(tierIndex, maxTokens, annualInterestRate, lockDuration);
     }
    function test_stakesSuccessfully() public {
        uint256 amount = 1000 ether;

        address user = address(0x1);
        token.transfer(user, amount);
        vm.startPrank(user);
        token.approve(address(tierStaking), amount);

        tierStaking.stake(amount);

        vm.stopPrank();
        (uint256 stakedAmount, uint8 stakedTierIndex, uint256 startTime) = tierStaking.userStakes(user, 0);
        assertEq(stakedAmount, amount);
        assertEq(stakedTierIndex, 0);
    }

    function test_staking_2tier() public {
        uint8 tierIndex = 1;
        uint256 maxTokens = 5000 ether;
        uint256 annualInterestRate = 3_000;
        uint256 lockDuration = 30 days;
        tierStaking.setupTier(tierIndex, maxTokens, annualInterestRate, lockDuration);
        address user = address(0x1);
        uint256 amount = 6000 ether;
        token.transfer(user, amount);
        vm.startPrank(user);
        token.approve(address(tierStaking), amount);

        tierStaking.stake(amount);

        vm.stopPrank();
        (uint256 stakedAmount, uint8 stakedTierIndex, uint256 startTime) = tierStaking.userStakes(user, 0);
        assertEq(stakedAmount, 5000 ether);
        assertEq(stakedTierIndex, 0);
        (uint256 stakedAmount1, uint8 stakedTierIndex1, uint256 startTime1) = tierStaking.userStakes(user, 1);
        assertEq(stakedAmount1, 1000 ether);
        assertEq(stakedTierIndex1, 1);
    }

}