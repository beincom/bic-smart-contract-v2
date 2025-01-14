// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {BICVesting} from "../../src/vest/BICVesting.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract BICVestingFuzzTest is Test {
    uint64 public constant DENOMINATOR = 10_000;

    BICVesting vesting;
    MockERC20 erc20;

    address beneficiary1 = address(0x123);
    address beneficiary2 = address(0x456);

    function setUp() public {
        // Deploy mock ERC20 token
        erc20 = new MockERC20();

        // Deploy BICVesting contract
        vesting = new BICVesting();
    }

    function testFuzz_initialize(
        uint256 totalAmount,
        uint16[] calldata fuzzedAllocations,
        uint16 redeemRate
    ) public {
        erc20.mint(address(vesting), totalAmount);

        if (totalAmount <= 0 || redeemRate == 0) {
            return;
        }

        bound(totalAmount, 1, 5_000_000_000 ether);
        bound(redeemRate, 1, DENOMINATOR);

        vm.assume(totalAmount > 0);
        vm.assume(redeemRate > 0);
        vm.assume(redeemRate <= DENOMINATOR);

        uint64 duration = 30 days;
        // Define beneficiaries dynamically based on the length of fuzzedAllocations
        uint256 length = fuzzedAllocations.length;
        if (length == 0) return; // Skip empty allocations to prevent errors

        address[] memory beneficiaries = new address[](length);
        uint16[] memory allocations = new uint16[](length);

        uint256 totalAllocations = 0;
        for (uint256 i = 0; i < length; i++) {
            // uint16(bound(fuzzedAllocations[i], 1, DENOMINATOR)); // 1 đến 100% (10_000 = 100%)
            if (
                fuzzedAllocations[i] <= 0 || fuzzedAllocations[i] > DENOMINATOR
            ) {
                return;
            }

            beneficiaries[i] = address(uint160(i + 1));
            allocations[i] = fuzzedAllocations[i];
            totalAllocations += allocations[i];
            vm.assume(totalAllocations == DENOMINATOR);
        }

        uint64 startTime = uint64(block.timestamp);

        // Fuzz test the initialize function
        vesting.initialize(
            address(erc20),
            totalAmount,
            beneficiaries,
            allocations,
            startTime,
            uint64(duration),
            uint64(redeemRate)
        );
        // Ensure the failure is expected based on the allocations
        uint16 _totalAllocation = 0;
        address[] memory list = vesting.getBeneficiaries();
        for (uint256 i = 0; i < allocations.length; i++) {
            _totalAllocation += vesting.getAllocation(list[i]).allocation;
        }
        assertEq(_totalAllocation, DENOMINATOR);

        uint256 amount = 0;
        uint256 stacksCounter = 0;
        uint256 leapDuration = 5;
        uint256 currentRewardStacks = 0;

        // uint256 amountPerDuration = vesting.amountPerDuration();
        uint256 maxRewardStacks = vesting.maxRewardStacks();
        uint256 buffer = DENOMINATOR % redeemRate > 0 ? 1 : 0;

        (amount, stacksCounter) = vesting.releasable();
        assertEq(amount, 0);
        assertEq(stacksCounter, 0);

        vm.warp(startTime + vesting.duration());
        (amount, stacksCounter) = vesting.releasable();
        uint256[] memory balancesPrev = new uint256[](length);
        uint256[] memory amountsAllocation = new uint256[](length);
        if (amount > 0) {
            for (uint256 i = 0; i < beneficiaries.length; i++) {
                balancesPrev[i] = erc20.balanceOf(beneficiaries[i]);
                amountsAllocation[i] = ((amount *
                    vesting.getAllocation(beneficiaries[i]).allocation) /
                    DENOMINATOR);
            }

            vesting.release();

            for (uint256 i = 0; i < beneficiaries.length; i++) {
                uint256 balanceNext = balancesPrev[i] + amountsAllocation[i];
                assertEq(erc20.balanceOf(beneficiaries[i]), balanceNext);
            }
        }

        // Test release 5 stack more
        currentRewardStacks = vesting.currentRewardStacks();
        if ((currentRewardStacks + leapDuration) < maxRewardStacks) {
            vm.warp(startTime + vesting.duration() * leapDuration);
            (amount, stacksCounter) = vesting.releasable();

            for (uint256 i = 0; i < beneficiaries.length; i++) {
                balancesPrev[i] = erc20.balanceOf(beneficiaries[i]);
                amountsAllocation[i] = ((amount *
                    vesting.getAllocation(beneficiaries[i]).allocation) /
                    DENOMINATOR);
            }

            vesting.release();

            for (uint256 i = 0; i < beneficiaries.length; i++) {
                uint256 balanceNext = balancesPrev[i] + amountsAllocation[i];
                assertEq(erc20.balanceOf(beneficiaries[i]), balanceNext);
            }
        }

        // Test release left over stacks
        currentRewardStacks = vesting.currentRewardStacks();
        uint256 leapOver = maxRewardStacks - currentRewardStacks;
        vm.warp(startTime + vesting.duration() * leapOver);
        (amount, stacksCounter) = vesting.releasable();

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            balancesPrev[i] = erc20.balanceOf(beneficiaries[i]);
            amountsAllocation[i] = ((amount *
                vesting.getAllocation(beneficiaries[i]).allocation) /
                DENOMINATOR);
        }

        vesting.release();

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            uint256 balanceNext = balancesPrev[i] + amountsAllocation[i];
            assertEq(erc20.balanceOf(beneficiaries[i]), balanceNext);
        }

        // Release end
        currentRewardStacks = vesting.currentRewardStacks();
        if (currentRewardStacks >= maxRewardStacks) {
            if (buffer > 0) {
                vm.warp(vesting.end() + 1);
                (amount, stacksCounter) = vesting.releasable();
                for (uint256 i = 0; i < beneficiaries.length; i++) {
                    balancesPrev[i] = erc20.balanceOf(beneficiaries[i]);
                    amountsAllocation[i] = ((amount *
                        vesting.getAllocation(beneficiaries[i]).allocation) /
                        DENOMINATOR);
                }

                vesting.release();

                for (uint256 i = 0; i < beneficiaries.length; i++) {
                    uint256 balanceNext = balancesPrev[i] +
                        amountsAllocation[i];
                    assertEq(erc20.balanceOf(beneficiaries[i]), balanceNext);
                }
            }
        }

        // Make sure all tokens are released
        assertEq(erc20.balanceOf(address(vesting)), 0);
    }
}
