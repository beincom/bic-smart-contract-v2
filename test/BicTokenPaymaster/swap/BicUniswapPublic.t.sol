// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BicStorage} from "../../../src/storage/BicStorage.sol";
import "../BicTokenPaymasterTestBase.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract BicForkUniswapV2 is BicTokenPaymasterTestBase {
    // Constants
    uint256 constant INIT_BIC_AMOUNT = 500000000 * 1e18;
    uint256 constant INIT_ETH_AMOUNT = 100 ether;
    // Pre-public round info
    uint256 round1Duration = 100;
    uint256 round2Duration = 200;
    uint256 coolDown1 = 5;
    uint256 maxAmountPerBuy1 = 10000 * 1e18;
    uint256 coolDown2 = 10;
    uint256 maxAmountPerBuy2 = 20000 * 1e18;

    // Liquidity fee info
    uint256 maxAllocation = 50000000 * 1e18;
    uint256 minSwapBackAndLiquify = 500000 * 1e18;
    uint256 maxLF = 1500;
    uint256 minLF = 300;
    uint256 LFReduction = 50;
    uint256 LFPeriod = 30 days;
    uint256 user1Balance = 5000000 * 1e18;
    uint256 user2Balance = 5000000 * 1e18;

    // Test addresses
    address user1 = address(0x2);
    address user2 = address(0x3);

    // Get LFStartTime
    uint256 LFStartTime = block.timestamp;

    // Pool variables
    IUniswapV2Pair pair;
    address[] path;

    function simulateLF(
        uint256 startTime,
        uint256 currentTime
    ) internal view returns (uint256) {
        uint256 totalReduction = ((currentTime - startTime) * LFReduction) /
            LFPeriod;

        if (totalReduction + minLF >= maxLF) {
            return minLF;
        } else {
            return maxLF - totalReduction;
        }
    }

    function simulateFee(
        uint256 amount,
        uint256 currentLF
    ) internal pure returns (uint256) {
        return (amount * currentLF) / 10000;
    }

    // Constants
    function setUp() public virtual override {
        super.setUp();

        // 1. First ensure owner has both ETH and BIC
        vm.deal(owner, 1000 ether);

        // Debug balances
        console.log("Owner BIC balance:", bic.balanceOf(owner));
        console.log("Owner ETH balance:", owner.balance);

        vm.startPrank(owner);

        // 2. Make sure the pair exists
        address pairAddress = getUniswapV2Pair();
        console.log("Pair address:", pairAddress);

        // 3. Clear any existing approvals first
        bic.approve(address(uniswapV2Router), 0);

        // 4. Approve new amount
        bic.approve(address(uniswapV2Router), type(uint256).max);
        console.log(
            "Router approval:",
            bic.allowance(owner, address(uniswapV2Router))
        );

        // Get reserves before
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pairAddress)
            .getReserves();
        console.log("Reserves before - BIC:", reserve0, "WETH:", reserve1);

        // 5. Add liquidity with more detailed error handling
        try
            uniswapV2Router.addLiquidityETH{value: INIT_ETH_AMOUNT}(
                address(bic),
                INIT_BIC_AMOUNT,
                0,
                0,
                owner,
                block.timestamp + 100
            )
        returns (uint amountToken, uint amountETH, uint liquidity) {
            console.log("Liquidity added successfully");
            console.log("BIC added:", amountToken);
            console.log("ETH added:", amountETH);
            console.log("LP tokens received:", liquidity);
        } catch Error(string memory reason) {
            console.log("Failed to add liquidity:", reason);
        } catch (bytes memory returnData) {
            console.log("Failed with raw error");
            console.logBytes(returnData);
        }

        vm.stopPrank();

        // Verify final state
        pair = IUniswapV2Pair(pairAddress);
        (reserve0, reserve1, ) = pair.getReserves();
        console.log("Reserves after - BIC:", reserve0, "WETH:", reserve1);
        console.log("LP tokens owned by owner:", pair.balanceOf(owner));

        vm.startPrank(owner);
        // Transfer initial balances
        bic.transfer(user1, user1Balance);
        bic.transfer(user2, user2Balance);
        console.log("bic of owner", bic.balanceOf(owner));
        console.log("eth of owner", owner.balance);

        // Mint WETH to users
        deal(address(weth), user1, 100 ether);
        deal(address(weth), user2, 100 ether);

        // Ensure owner has enough tokens
        assertGe(
            bic.balanceOf(owner),
            INIT_BIC_AMOUNT,
            "Owner doesn't have enough tokens"
        );

        // Check ETH balance
        assertGe(
            owner.balance,
            INIT_ETH_AMOUNT,
            "Owner doesn't have enough ETH"
        );

        // Setup path and pair
        path = new address[](2);
        path[0] = address(weth);
        path[1] = address(bic);
        // Get the pool address and create pair interface
        address pool = getUniswapV2Pair();
        pair = IUniswapV2Pair(pool);
        // Verify pool setup
        assertTrue(pair.balanceOf(owner) > 0, "Pool setup failed");
    }

    function test_checking_fee() public view {
        // Check liquidity fee related info
        assertEq(getLFReduction(), LFReduction, "LFReduction mismatch");
        assertEq(getLFPeriod(), LFPeriod, "LFPeriod mismatch");
        assertEq(getMaxLF(), maxLF, "maxLF mismatch");
        assertEq(getMinLF(), minLF, "minLF mismatch");
        assertEq(
            getUniswapV2Pair(),
            address(pair),
            "uniswapV2Pair mismatch"
        );
    }

    function test_simu2late_current_liquidity_fee_after_period() public {
        // Calculate target time: LFStartTime + (LFPeriod * 2) + 1
        uint256 currentTime = LFStartTime + (LFPeriod * 2) + 1;

        // Increase block timestamp to target time
        vm.warp(currentTime);

        // Calculate expected LF
        uint256 expectedLF = simulateLF(LFStartTime, currentTime);

        // Get actual current LF
        uint256 currentLF = bic.getCurrentLF();

        // Assert they match
        assertEq(
            currentLF,
            expectedLF,
            "Current LF doesn't match expected value"
        );
    }

    function test_simulate_swap_weth_to_bic_at_max_lf() public {
        // Disable pre-public
        vm.startPrank(owner);
        bic.setPrePublic(false);
        vm.stopPrank();

        // Approve WETH spending
        vm.startPrank(user1);
        weth.approve(address(uniswapV2Router), type(uint256).max);
        vm.stopPrank();

        // Check current LF is at max
        uint256 currentLF = bic.getCurrentLF();
        assertEq(currentLF, maxLF, "Current LF should be at max");

        // Setup swap parameters
        uint256 swapAmount = 0.1 ether;
        uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
            swapAmount,
            path
        );

        // Verify swap won't exceed max allocation
        assertLt(
            user1Balance + amountOuts[1],
            maxAllocation,
            "Swap would exceed max allocation"
        );

        // Execute swap
        vm.startPrank(user1);
        uniswapV2Router.swapExactTokensForTokens(
            swapAmount,
            0, // min amount out
            path,
            user1,
            block.timestamp + 60
        );
        vm.stopPrank();

        // Verify final balances
        assertEq(
            bic.balanceOf(address(bic)),
            0,
            "BIC contract should have 0 balance"
        );
        assertEq(
            bic.balanceOf(user1),
            user1Balance + amountOuts[1],
            "User1 should have received correct BIC amount"
        );
    }

    function test_simulate_swap_weth_to_bic_at_current_lf() public {
        // Disable pre-public
        vm.startPrank(owner);
        bic.setPrePublic(false);
        vm.stopPrank();

        // Set time and check LF
        uint256 currentTime = LFStartTime + LFPeriod * 2 + 1;
        vm.warp(currentTime);

        uint256 currentLF = bic.getCurrentLF();
        uint256 estLF = simulateLF(LFStartTime, currentTime);

        // Check LF conditions
        assertEq(currentLF, estLF, "Current LF should match estimated LF");
        assertLe(
            currentLF,
            maxLF,
            "Current LF should be less than or equal to maxLF"
        );
        assertGe(
            currentLF,
            minLF,
            "Current LF should be greater than or equal to minLF"
        );

        // Setup swap parameters
        uint256 swapAmount = 0.1 ether;
        uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
            swapAmount,
            path
        );

        // Verify swap won't exceed max allocation
        assertLe(
            user1Balance + amountOuts[1],
            maxAllocation,
            "Swap would exceed max allocation"
        );

        // Give user1 some ETH for the swap
        vm.deal(user1, 10 ether);

        // Execute swap
        vm.startPrank(user1);
        uniswapV2Router.swapExactETHForTokens{value: swapAmount}(
            0, // min amount out
            path,
            user1,
            currentTime + 60
        );
        vm.stopPrank();

        // Verify final balances
        assertEq(
            bic.balanceOf(address(bic)),
            0,
            "BIC contract should have 0 balance"
        );
        assertEq(
            bic.balanceOf(user1),
            user1Balance + amountOuts[1],
            "User1 should have received correct BIC amount"
        );
    }

    function test_simulate_swap_weth_to_bic_over_max_allocation() public {
        // Disable pre-public
        vm.startPrank(owner);
        bic.setPrePublic(false);
        vm.stopPrank();

        // Approve WETH spending
        vm.startPrank(user1);
        weth.approve(address(uniswapV2Router), type(uint256).max);
        vm.stopPrank();

        // Set time and check LF
        uint256 currentTime = LFStartTime + LFPeriod * 2 + 1;
        vm.warp(currentTime);

        uint256 currentLF = bic.getCurrentLF();
        uint256 estLF = simulateLF(LFStartTime, currentTime);

        // Check LF conditions
        assertEq(currentLF, estLF, "Current LF should match estimated LF");
        assertLe(
            currentLF,
            maxLF,
            "Current LF should be less than or equal to maxLF"
        );
        assertGe(
            currentLF,
            minLF,
            "Current LF should be greater than or equal to minLF"
        );

        // Setup swap parameters with larger amount
        uint256 swapAmount = 20 ether; // Increased amount to trigger max allocation error
        uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
            swapAmount,
            path
        );

        // Verify swap would exceed max allocation
        assertGt(
            user1Balance + amountOuts[1],
            maxAllocation,
            "Swap should exceed max allocation"
        );

        // Execute swap and expect it to revert
        vm.startPrank(user1);
        uniswapV2Router.swapExactTokensForTokens(
            swapAmount,
            0, // min amount out
            path,
            user1,
            currentTime + 60
        );
        vm.stopPrank();
    }

    function test_simulate_swap_bic_to_weth_at_current_lf() public {
        // Disable pre-public
        vm.startPrank(owner);
        bic.setPrePublic(false);
        vm.stopPrank();

        // Approve BIC spending
        vm.startPrank(user1);
        bic.approve(address(uniswapV2Router), type(uint256).max);
        vm.stopPrank();

        // Set time and check LF
        uint256 currentTime = LFStartTime + LFPeriod * 2 + 1;
        vm.warp(currentTime);

        uint256 currentLF = bic.getCurrentLF();
        uint256 estLF = simulateLF(LFStartTime, currentTime);

        // Check LF conditions
        assertEq(currentLF, estLF, "Current LF should match estimated LF");
        assertLe(
            currentLF,
            maxLF,
            "Current LF should be less than or equal to maxLF"
        );
        assertGe(
            currentLF,
            minLF,
            "Current LF should be greater than or equal to minLF"
        );

        // Setup swap parameters
        uint256 swapAmount = 10 ether;
        address[] memory swapPath = new address[](2);
        swapPath[0] = address(bic);
        swapPath[1] = address(weth);

        // uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
        //     swapAmount,
        //     swapPath
        // );

        // Calculate expected fee
        uint256 expectedFee = simulateFee(swapAmount, currentLF);

        // Execute swap
        vm.startPrank(user1);
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            swapAmount,
            0, // min amount out
            swapPath,
            user1,
            currentTime + 60
        );
        vm.stopPrank();

        // Verify final balance
        assertEq(
            bic.balanceOf(address(bic)),
            expectedFee,
            "BIC contract should have correct fee amount"
        );
    }

    function test_simulate_swap_back_and_liquify_with_eth() public {
        // Disable pre-public
        vm.startPrank(owner);
        bic.setPrePublic(false);
        vm.stopPrank();

        // Approve BIC spending for user1
        vm.startPrank(user1);
        bic.approve(address(uniswapV2Router), type(uint256).max);
        vm.stopPrank();

        // Set time and check LF
        uint256 currentTime = LFStartTime + LFPeriod * 2 + 1;
        vm.warp(currentTime);

        uint256 currentLF = bic.getCurrentLF();
        uint256 estLF = simulateLF(LFStartTime, currentTime);
        uint256 deadline = currentTime + 60;

        // Check LF conditions
        assertEq(currentLF, estLF, "Current LF should match estimated LF");
        assertLt(currentLF, maxLF, "Current LF should be less than maxLF");
        assertGt(currentLF, minLF, "Current LF should be greater than minLF");

        // Setup swap parameters for user1
        uint256 swapAmount = maxAllocation / 10;
        address[] memory swapPath = new address[](2);
        swapPath[0] = address(bic);
        swapPath[1] = address(weth);

        uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
            swapAmount,
            swapPath
        );

        // Calculate expected fee
        uint256 fee = simulateFee(swapAmount, currentLF);
        assertGt(
            fee,
            minSwapBackAndLiquify,
            "Fee should be greater than minSwapBackAndLiquify"
        );

        // Execute first swap
        vm.startPrank(user1);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            swapAmount,
            0, // min amount out
            swapPath,
            user1,
            deadline
        );
        vm.stopPrank();

        // Check accumulated LF
        uint256 bicBalance = bic.balanceOf(address(bic));
        uint256 accumulatedLF = getAccumulatedLF();
        assertEq(bicBalance, fee, "BIC balance should equal fee");
        assertEq(
            bicBalance,
            accumulatedLF,
            "BIC balance should equal accumulated LF"
        );
        assertGt(
            bicBalance,
            minSwapBackAndLiquify,
            "BIC balance should be greater than minSwapBackAndLiquify"
        );

        // Store LP balance before second swap
        uint256 LFBalanceBefore = pair.balanceOf(owner);

        // Setup user2 swap
        vm.startPrank(user2);
        bic.approve(address(uniswapV2Router), type(uint256).max);

        uint256 swapAmount2 = maxAllocation / 10;
        uint256 fee2 = simulateFee(swapAmount2, currentLF);

        // Execute second swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            swapAmount2,
            0,
            swapPath,
            user2,
            deadline
        );
        vm.stopPrank();
        uint256 LFBalanceAfter = pair.balanceOf(owner);

        // Check final states
        uint256 accumulatedLFAfterSwapBack = getAccumulatedLF();

        assertLt(
            accumulatedLFAfterSwapBack,
            fee + fee2,
            "Accumulated LF should be less than total fees"
        );
        assertGt(
            LFBalanceAfter,
            LFBalanceBefore,
            "LP balance should have increased"
        );
    }
}
