// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {BicTokenPaymasterWithoutPreSetupExchange} from"../contracts/BicTokenPaymasterWithoutPreSetupExchange.sol";
import "../../src/staking/TieredStakingPool.sol";
import "forge-std/Test.sol";

contract TieredStakingPoolTest is Test {
    BicTokenPaymasterWithoutPreSetupExchange token;
    TieredStakingPool tierStaking;
    address[] signers = [0xeaBcd21B75349c59a4177E10ed17FBf2955fE697];

    function setUp() public {

        token = new BicTokenPaymasterWithoutPreSetupExchange(
        0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
        address(this),
        signers
        );
        tierStaking = new TieredStakingPool(token, address(this));
        uint256 maxTokens = 5000 ether;
        uint256 annualInterestRate = 3_000;
        uint256 lockDuration = 365 days;
        tierStaking.addTier(maxTokens, annualInterestRate, lockDuration);
    }

    function test_stakesSuccessfully() public {
        uint256 amount = 1000 ether;

        address user = address(0x1);
        token.transfer(user, amount);
        vm.startPrank(user);
        token.approve(address(tierStaking), amount);

        tierStaking.deposit(amount);

        vm.stopPrank();
        (uint256 stakedAmount, uint256 stakedTierIndex, uint256 startTime, bool isWithdraw) = tierStaking.deposits(user, 0);
        assertEq(stakedAmount, amount);
        assertEq(stakedTierIndex, 0);
        assertEq(isWithdraw, false);
    }

    function test_staking_2tier() public {
        uint256 maxTokens = 5000 ether;
        uint256 annualInterestRate = 2_000;
        uint256 lockDuration = 365 days;
        tierStaking.addTier(maxTokens, annualInterestRate, lockDuration);
        address user = address(0x1);
        uint256 amount = 6000 ether;
        token.transfer(user, amount);
        vm.startPrank(user);
        token.approve(address(tierStaking), amount);

        tierStaking.deposit(amount);

        vm.stopPrank();
        TieredStakingPool.Deposit[] memory depositInfo = tierStaking.getUserDeposits(user);
        assertEq(depositInfo.length, 2);
        assertEq(depositInfo[0].amount, 5000 ether);
        assertEq(depositInfo[1].amount, 1000 ether);

        TieredStakingPool.Tier[] memory tiers = tierStaking.getTiers();
        assertEq(tiers[0].totalStaked, 5000 ether);
        assertEq(tiers[1].totalStaked, 1000 ether);
    }

    function test_stakes_and_withdraw_all_success() public {
        uint256 maxTokens = 5000 ether;
        uint256 annualInterestRate = 2_000;
        uint256 lockDuration = 365 days;
        tierStaking.addTier(maxTokens, annualInterestRate, lockDuration);
        uint256 amount = 6000 ether;

        address user = address(0x1);
        token.transfer(user, amount);
        token.transfer(address(tierStaking), amount);
        vm.startPrank(user);
        token.approve(address(tierStaking), amount);

        tierStaking.deposit(amount);

        vm.stopPrank();
        (uint256 stakedAmount, uint256 stakedTierIndex, uint256 startTime, bool isWithdraw) = tierStaking.deposits(user, 0);

        vm.warp(block.timestamp + 365 days + 1);
        vm.startPrank(user);
        tierStaking.withdrawAll();
        vm.stopPrank();
        assertEq(token.balanceOf(user), maxTokens*13/10 + (amount-maxTokens)*12/10);
    }

    function test_stakes_and_withdraw_batch_success() public {
        uint256 maxTokens = 5000 ether;
        uint256 annualInterestRate = 2_000;
        uint256 lockDuration = 365 days;
        tierStaking.addTier(maxTokens, annualInterestRate, lockDuration);
        uint256 amount = 6000 ether;

        address user = address(0x1);
        token.transfer(user, amount);
        token.transfer(address(tierStaking), amount);
        vm.startPrank(user);
        token.approve(address(tierStaking), amount);
        tierStaking.deposit(amount);
        vm.stopPrank();
        vm.warp(block.timestamp + 365 days + 1);
        vm.startPrank(user);
        tierStaking.withdrawBatch(1, 1);
        vm.stopPrank();
        assertEq(token.balanceOf(user), (amount-maxTokens)*12/10);
    }

    function test_stakes_and_withdraw_batch_6month_success() public {
        uint256 maxTokens = 5000 ether;
        uint256 annualInterestRate = 2_000;
        uint256 lockDuration = 180 days;
        tierStaking.addTier(maxTokens, annualInterestRate, lockDuration);
        uint256 amount = 6000 ether;

        address user = address(0x1);
        token.transfer(user, amount);
        token.transfer(address(tierStaking), amount);
        vm.startPrank(user);
        token.approve(address(tierStaking), amount);
        tierStaking.deposit(amount);
        vm.stopPrank();
        vm.warp(block.timestamp + 365 days + 1);
        vm.startPrank(user);
        tierStaking.withdrawBatch(1, 1);
        vm.stopPrank();
        uint256 tier1StakedAmount = (amount-maxTokens);
        assertEq(token.balanceOf(user), tier1StakedAmount + tier1StakedAmount*annualInterestRate*lockDuration/(365 days * 10000));
    }
}