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

    function test_depositIntoTier_deposit_toTier1() public {
        uint256 maxTokens = 5000 ether;
        uint256 annualInterestRate = 2_000;
        uint256 lockDuration = 180 days;
        tierStaking.addTier(maxTokens, annualInterestRate, lockDuration);
        uint256 amount = 1000 ether;

        address user = address(0x1);
        token.transfer(user, amount);
        token.transfer(address(tierStaking), amount);
        vm.startPrank(user);
        token.approve(address(tierStaking), amount);
        tierStaking.depositIntoTier(1, amount);
        vm.stopPrank();
        TieredStakingPool.Deposit[] memory depositInfo = tierStaking.getUserDeposits(user);
        assertEq(depositInfo.length, 1);
        assertEq(depositInfo[0].amount, amount);
        assertEq(depositInfo[0].tierIndex, 1);
    }

    function test_deposit2TimeOnSameTier() public {
        uint256 amount = 1000 ether;
        address user = address(0x1);
        uint256 amount2 = 2000 ether;
        token.transfer(user, amount + amount2);
        vm.startPrank(user);
        token.approve(address(tierStaking), amount);
        tierStaking.deposit(amount);
        token.approve(address(tierStaking), amount2);
        tierStaking.deposit(amount2);
        vm.stopPrank();
        TieredStakingPool.Deposit[] memory depositInfo = tierStaking.getUserDeposits(user);
        assertEq(depositInfo.length, 2);
        assertEq(depositInfo[0].amount, amount);
        assertEq(depositInfo[1].amount, amount2);
    }

    function test_deposit2TimeOnSameTier_usingDepositTier() public {
        uint256 amount = 1000 ether;
        address user = address(0x1);
        uint256 amount2 = 2000 ether;
        token.transfer(user, amount + amount2);
        vm.startPrank(user);
        token.approve(address(tierStaking), amount);
        tierStaking.depositIntoTier(0,amount);
        token.approve(address(tierStaking), amount2);
        tierStaking.depositIntoTier(0, amount2);
        vm.stopPrank();
        TieredStakingPool.Deposit[] memory depositInfo = tierStaking.getUserDeposits(user);
        assertEq(depositInfo.length, 2);
        assertEq(depositInfo[0].amount, amount);
        assertEq(depositInfo[1].amount, amount2);
    }

    function test_revertWhenDepositZero() public {
        uint256 amount = 0;
        address user = address(0x1);
        token.transfer(user, amount);
        vm.startPrank(user);
        token.approve(address(tierStaking), amount);
        vm.expectRevert(abi.encodeWithSelector(TieredStakingPool.ZeroStakeAmount.selector));
        tierStaking.deposit(amount);
    }

    function test_revertWhenNotEnoughCapacityInTier() public {
        uint256 amount = 6000 ether;
        address user = address(0x1);
        token.transfer(user, amount);
        vm.startPrank(user);
        token.approve(address(tierStaking), amount);
        vm.expectRevert(abi.encodeWithSelector(TieredStakingPool.NotEnoughCapacityInTier.selector));
        tierStaking.deposit(amount);
    }

    function test_revertWhenWithdrawBeforeLockDuration() public {
        uint256 amount = 1000 ether;
        address user = address(0x1);
        token.transfer(user, amount);
        vm.startPrank(user);
        token.approve(address(tierStaking), amount);
        tierStaking.deposit(amount);
        vm.stopPrank();
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(TieredStakingPool.ZeroWithdrawAmount.selector));
        tierStaking.withdrawAll();
    }

    function test_revertWhenWithdrawBeforeLockDuration_usingWithdrawBatch() public {
        uint256 amount = 1000 ether;
        address user = address(0x1);
        token.transfer(user, amount);
        vm.startPrank(user);
        token.approve(address(tierStaking), amount);
        tierStaking.deposit(amount);
        vm.stopPrank();
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(TieredStakingPool.ZeroWithdrawAmount.selector));
        tierStaking.withdrawBatch(0, 1);
    }

    function test_revertWhenDepositIntoTier1_WhenTier1NotExist() public {
        uint256 amount = 1000 ether;
        address user = address(0x1);
        token.transfer(user, amount);
        vm.startPrank(user);
        token.approve(address(tierStaking), amount);
        vm.expectRevert(abi.encodeWithSelector(TieredStakingPool.InvalidTierIndex.selector, 1));
        tierStaking.depositIntoTier(1, amount);
    }
}