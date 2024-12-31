// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BICVestingTestBase} from "./BICVestingTestBase.sol";
import {BICVesting} from "../../src/vest/BICVesting.sol";
import {Test, console} from "forge-std/Test.sol";

contract BICVestingTest is BICVestingTestBase {
    function test_early_redeem() public {
        address vestingContract = getVestingContract(redeem1);
        BICVesting bicVesting = BICVesting(vestingContract);
        (uint256 amount, uint256 stacks) = bicVesting.releasable();
        assertEq(amount, 0);
        assertEq(stacks, 0);
        vm.startPrank(redeemer1);
        vm.expectRevert();
        bicVesting.release();
    }

    function test_redeem_first_stack() public {
        address vestingContract = getVestingContract(redeem1);
        BICVesting bicVesting = BICVesting(vestingContract);
        vm.warp(block.timestamp + redeem1.duration);
        assertEq(testERC20.balanceOf(redeemer1), 0);
        (uint256 amount, uint256 stacks) = bicVesting.releasable();
        assertGt(amount, 0);
        assertEq(stacks, 1);
        vm.startPrank(redeemer1);
        bicVesting.release();
        // assertEq(amount, testERC20.balanceOf(redeemer1) + testERC20.balanceOf(redeemer2));
        // assertEq(amount * redeem1.allocations[0] / 10000, testERC20.balanceOf(redeemer1));
    }

    function test_accumulate_multiple_stacks() public {
        address vestingContract = getVestingContract(redeem1);
        BICVesting bicVesting = BICVesting(vestingContract);

        // Advance 4 durations
        vm.warp(block.timestamp + (redeem1.duration * 4));

        (uint256 amount, uint256 stacks) = bicVesting.releasable();
        assertEq(stacks, 4);
        assertEq(amount, bicVesting.amountPerDuration() * 4);

        vm.startPrank(redeemer1);
        bicVesting.release();

        // Check both beneficiaries received their correct proportions
        assertEq(
            testERC20.balanceOf(redeemer1),
            (amount * redeem1.allocations[0]) / bicVesting.DENOMINATOR()
        );
        assertEq(
            testERC20.balanceOf(redeemer2),
            (amount * redeem1.allocations[1]) / bicVesting.DENOMINATOR()
        );
    }

    function test_prevent_duplicate_redeem_creation() public {
        vm.startPrank(owner);
        vm.expectRevert(); // Should revert when trying to create the same redeem twice
        createVesting(redeem1);
    }

    function test_correct_beneficiary_allocation_percentages() public {
        address vestingContract = getVestingContract(redeem1);
        BICVesting bicVesting = BICVesting(vestingContract);

        vm.warp(block.timestamp + redeem1.duration);

        (uint256 amount, ) = bicVesting.releasable();
        vm.startPrank(redeemer1);
        bicVesting.release();

        uint256 redeemer1Amount = testERC20.balanceOf(redeemer1);
        uint256 redeemer2Amount = testERC20.balanceOf(redeemer2);

        // Verify 70-30 split using DENOMINATOR
        assertEq(redeemer1Amount, (amount * 7000) / bicVesting.DENOMINATOR()); // 70%
        assertEq(redeemer2Amount, (amount * 3000) / bicVesting.DENOMINATOR()); // 30%
    }

    function test_release_after_end_time() public {
        address vestingContract = getVestingContract(redeem1);
        BICVesting bicVesting = BICVesting(vestingContract);

        // Warp to after end time
        vm.warp(block.timestamp + (redeem1.duration * 51)); // Assuming 50 stacks (10000/200)

        (uint256 amount, ) = bicVesting.releasable();
        assertEq(amount, redeem1.totalAmount - bicVesting.released());
    }

    function test_zero_release_between_stacks() public {
        address vestingContract = getVestingContract(redeem1);
        BICVesting bicVesting = BICVesting(vestingContract);

        // Warp to middle of first duration
        vm.warp(block.timestamp + (redeem1.duration / 2));

        (uint256 amount, uint256 stacks) = bicVesting.releasable();
        assertEq(amount, 0);
        assertEq(stacks, 0);
    }

    function test_multiple_releases_same_stack() public {
        address vestingContract = getVestingContract(redeem1);
        BICVesting bicVesting = BICVesting(vestingContract);

        vm.warp(block.timestamp + redeem1.duration);

        vm.startPrank(redeemer1);
        bicVesting.release();

        // Try to release again in same stack
        vm.expectRevert(); // Should revert with NoRelease
        bicVesting.release();
    }

    function test_correct_max_reward_stacks() public {
        address vestingContract = getVestingContract(redeem1);
        BICVesting bicVesting = BICVesting(vestingContract);

        // For redeemRate of 200, maxRewardStacks should be 50 (DENOMINATOR/200)
        assertEq(bicVesting.maxRewardStacks(), bicVesting.DENOMINATOR() / 200);
    }

    function test_partial_release_tracking() public {
        address vestingContract = getVestingContract(redeem1);
        BICVesting bicVesting = BICVesting(vestingContract);

        vm.warp(block.timestamp + redeem1.duration);

        uint256 initialReleased = bicVesting.released();
        vm.startPrank(redeemer1);
        bicVesting.release();

        assertGt(bicVesting.released(), initialReleased);
        assertEq(bicVesting.currentRewardStacks(), 1);
    }

    function test_release_full_amount_over_time() public {
        address vestingContract = getVestingContract(redeem1);
        BICVesting bicVesting = BICVesting(vestingContract);

        // Release all stacks one by one
        for (uint i = 0; i < 50; i++) {
            vm.warp(block.timestamp + redeem1.duration);
            vm.startPrank(redeemer1);
            bicVesting.release();
            vm.stopPrank();
        }

        assertEq(bicVesting.released(), redeem1.totalAmount);
    }

    function test_beneficiaries_list_accuracy() public {
        address vestingContract = getVestingContract(redeem1);
        BICVesting bicVesting = BICVesting(vestingContract);

        address[] memory storedBeneficiaries = bicVesting.getBeneficiaries();
        assertEq(storedBeneficiaries.length, 2);
        assertEq(storedBeneficiaries[0], redeemer1);
        assertEq(storedBeneficiaries[1], redeemer2);
    }

    function test_prevent_duplicate_beneficiaries() public {
        // Create new redeem info with duplicate beneficiaries
        address[] memory duplicateBeneficiaries = new address[](2);
        duplicateBeneficiaries[0] = redeemer1;
        duplicateBeneficiaries[1] = redeemer1; // Same address as first beneficiary

        uint16[] memory duplicateAllocations = new uint16[](2);
        duplicateAllocations[0] = 7000;
        duplicateAllocations[1] = 3000;

        CreateRedeem memory duplicateRedeem = CreateRedeem({
            token: address(testERC20),
            totalAmount: 1e21,
            beneficiaries: duplicateBeneficiaries,
            allocations: duplicateAllocations,
            duration: 1000,
            redeemRate: 200
        });

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSignature("DuplicateBeneficiary(address)", redeemer1)
        ); // Expect specific error with the duplicate address
        bicVestingFactory.createRedeem(
            duplicateRedeem.token,
            duplicateRedeem.totalAmount,
            duplicateRedeem.beneficiaries,
            duplicateRedeem.allocations,
            duplicateRedeem.duration,
            duplicateRedeem.redeemRate
        );
        vm.stopPrank();
    }
}
