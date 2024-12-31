// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BICVestingTestBase} from "./BICVestingTestBase.sol";
import {BICVesting} from "../../src/vest/BICVesting.sol";
import {Test, console} from "forge-std/Test.sol";

contract BICVestingTest is BICVestingTestBase {
    uint64 public constant DOMINATOR = 10_000;
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
        uint256 allocation1 = bicVesting._redeemAllocations();
        vm.warp(block.timestamp + redeem1.duration);
        assertEq(testERC20.balanceOf(redeemer1), 0);
        (uint256 amount, uint256 stacks) = bicVesting.releasable();
        assertGt(amount, 0);
        assertEq(stacks, 1);
        vm.startPrank(redeemer1);
        bicVesting.release();

        // assertEq(amount, testERC20.balanceOf(redeemer1) + testERC20.balanceOf(redeemer2));
        //assertEq(amount * redeem1.allocations[0] / DOMINATOR, testERC20.balanceOf(redeemer1));
    }

    function test_SuccessRedeemOtherStack() public {
        
    }
}