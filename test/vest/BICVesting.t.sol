// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BICVestingTestBase} from "./BICVestingTestBase.sol";
import {BICVesting} from "../../src/vest/BICVesting.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BICVestingTest is BICVestingTestBase {
    uint64 public constant DENOMINATOR = 10_000;
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

    function test_SuccessRedeemFirstStack() public {
        address vestingContract = getVestingContract(redeem1);
        BICVesting bicVesting = BICVesting(vestingContract);

        BICVesting.RedeemAllocation memory alloc1 = bicVesting.getAllocation(
            redeemer1
        );
        BICVesting.RedeemAllocation memory alloc2 = bicVesting.getAllocation(
            redeemer2
        );

        vm.warp(block.timestamp + redeem1.duration);

        assertEq(testERC20.balanceOf(redeemer1), 0);
        (uint256 amount, uint256 stacks) = bicVesting.releasable();

        uint256 amount1Expect = (amount * alloc1.allocation) / DENOMINATOR;
        uint256 amount2Expect = (amount * alloc1.allocation) / DENOMINATOR;

        assertGt(amount, 0);
        assertEq(stacks, 1);
        vm.startPrank(redeemer1);
        bicVesting.release();

        // assertEq(amount, testERC20.balanceOf(redeemer1) + testERC20.balanceOf(redeemer2));
        //assertEq(amount * redeem1.allocations[0] / DENOMINATOR, testERC20.balanceOf(redeemer1));
    }

    function test_SuccessRedeemOtherStack() public {}

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
        vm.stopPrank();
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
        address[] memory beneficiaries = bicVesting.getBeneficiaries();
        IERC20 erc20 = IERC20(bicVesting.erc20());
        uint256 length = beneficiaries.length;
        vm.warp(block.timestamp + redeem1.duration);
        (uint256 amount, uint256 stacks) = bicVesting.releasable();
        uint256[] memory balancesPrev = new uint256[](length);
        uint256[] memory amountsAllocation = new uint256[](length);
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            balancesPrev[i] = erc20.balanceOf(beneficiaries[i]);
            amountsAllocation[i] = ((amount *
                bicVesting.getAllocation(beneficiaries[i]).allocation) /
                DENOMINATOR);
            console.log(
                "Changing owner from %e to %e",
                balancesPrev[i],
                amountsAllocation[i]
            );
        }
        uint256 initialReleased = bicVesting.released();
        vm.startPrank(redeemer1);
        bicVesting.release();
        vm.stopPrank();

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            uint256 balanceNext = balancesPrev[i] +
                amountsAllocation[i];
            console.log("Changing owner from %e", balanceNext);
            assertEq(erc20.balanceOf(beneficiaries[i]), balanceNext);
        }

        assertGt(bicVesting.released(), initialReleased);
        assertEq(bicVesting.currentRewardStacks(), 1);
    }

    function test_release_full_amount_over_time() public {
        address vestingContract = getVestingContract(redeem1);
        BICVesting bicVesting = BICVesting(vestingContract);

        address[] memory beneficiaries = bicVesting.getBeneficiaries();
        IERC20 erc20 = IERC20(bicVesting.erc20());
        uint256 length = beneficiaries.length;

        uint64 maxRewardStacks = bicVesting.maxRewardStacks();
        uint256[] memory balancesPrev = new uint256[](length);
        uint256[] memory amountsAllocation = new uint256[](length);

        // Release all stacks one by one
        for (uint64 i = 0; i < maxRewardStacks; i++) {
            vm.warp(block.timestamp + redeem1.duration);
            (uint256 amount, uint256 stacks) = bicVesting.releasable();

            for (uint256 i = 0; i < beneficiaries.length; i++) {
                balancesPrev[i] = erc20.balanceOf(beneficiaries[i]);
                amountsAllocation[i] = ((amount *
                    bicVesting.getAllocation(beneficiaries[i]).allocation) /
                    DENOMINATOR);
                console.log(
                    "Changing owner from %e to %e",
                    balancesPrev[i],
                    amountsAllocation[i]
                );
            }
            vm.startPrank(redeemer1);
            bicVesting.release();
            vm.stopPrank();

            for (uint256 i = 0; i < beneficiaries.length; i++) {
                uint256 balanceNext = balancesPrev[i] +
                    amountsAllocation[i];
                console.log("Changing owner from %e", balanceNext);
                assertEq(erc20.balanceOf(beneficiaries[i]), balanceNext);
            }
        }

        assertEq(bicVesting.released(), redeem1.totalAmount);
    }

    function test_beneficiaries_list_accuracy() public {
        address vestingContract = getVestingContract(redeem1);
        BICVesting bicVesting = BICVesting(payable(vestingContract));

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
            redeemRate: 200,
            nonce: 0 
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
            duplicateRedeem.redeemRate,
            duplicateRedeem.nonce
        );
        vm.stopPrank();
    }

    // TODO: Fix this test - still has dust
    function test_final_release_transfers_all_remaining() public {
        // Create new redeem with odd total amount
        address[] memory beneficiaries = new address[](2);
        address redeemer1 = address(uint160(block.timestamp + 1));
        address redeemer2 = address(uint160(block.timestamp + 2));
        beneficiaries[0] = redeemer1;
        beneficiaries[1] = redeemer2;

        uint16[] memory allocations = new uint16[](2);
        allocations[0] = 7000; // 70%
        allocations[1] = 3000; // 30%

        CreateRedeem memory oddRedeem = CreateRedeem({
            token: address(testERC20),
            totalAmount: 3333, // Odd amount that will create dust
            beneficiaries: beneficiaries,
            allocations: allocations,
            duration: 1000,
            redeemRate: 200,
            nonce: 0
        });

        createVesting(oddRedeem);
        address vestingContract = getVestingContract(oddRedeem);
        BICVesting bicVesting = BICVesting(payable(vestingContract));

        // Warp to after end time
        vm.warp(bicVesting.end() + 1);
        vm.startPrank(redeemer1);
        bicVesting.release();
        vm.stopPrank();

        // Verify contract has zero balance after final release
        assertEq(
            testERC20.balanceOf(address(bicVesting)),
            0,
            "Contract should have zero balance"
        );
    }
    
    function test_dust_handling_with_odd_amount() public {
        // Create new redeem with odd total amount
        address[] memory beneficiaries = new address[](2);
        address redeemer1 = address(uint160(block.timestamp + 1));
        address redeemer2 = address(uint160(block.timestamp + 2));

        beneficiaries[0] = redeemer1;
        beneficiaries[1] = redeemer2;

        uint16[] memory allocations = new uint16[](2);
        allocations[0] = 7000; // 70%
        allocations[1] = 3000; // 30%

        CreateRedeem memory oddRedeem = CreateRedeem({
            token: address(testERC20),
            totalAmount: 3333, // Odd amount that will create dust
            beneficiaries: beneficiaries,
            allocations: allocations,
            duration: 1000,
            redeemRate: 200,
            nonce: 0
        });
        createVesting(oddRedeem);

        address vestingContract = getVestingContract(oddRedeem);

        BICVesting bicVesting = BICVesting(payable(vestingContract));

        // Advance one duration
        vm.warp(block.timestamp + oddRedeem.duration);
        vm.startPrank(redeemer1);
        bicVesting.release();
        vm.stopPrank();

        // Check that rounding doesn't lose any tokens
        uint256 totalReleased = testERC20.balanceOf(redeemer1) +
            testERC20.balanceOf(redeemer2);
        // less than amountPerDuration because of dust
        assertGe(totalReleased, bicVesting.amountPerDuration());
    }
}
