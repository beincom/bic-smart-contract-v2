// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {B139Storage} from "../../../src/storage/B139Storage.sol";
import "../B139TestBase.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract BicUniswapPrePublic is B139TestBase {
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
    address user3 = address(0x4);

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
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);

        // Debug balances
        console.log("Owner BIC balance:", bic.balanceOf(owner));
        console.log("Owner ETH balance:", owner.balance);

        vm.startPrank(owner);

        // 2. Make sure the pair exists
        address pairAddress = bic.getUniswapV2Pair();
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

        // Setup pre-public whitelist
        address[] memory addresses = new address[](2);
        addresses[0] = user1;
        addresses[1] = user2;
        uint256[] memory categories = new uint256[](2);
        categories[0] = 1;
        categories[1] = 2;

        vm.prank(owner);
        bic.setPrePublicWhitelist(addresses, categories);

        // Setup pre-public rounds
        B139Storage.PrePublic memory round1 = B139Storage.PrePublic({
            category: 1,
            startTime: LFStartTime + 10,
            endTime: LFStartTime + 10 + round1Duration,
            coolDown: coolDown1,
            maxAmountPerBuy: maxAmountPerBuy1
        });

        B139Storage.PrePublic memory round2 = B139Storage.PrePublic({
            category: 2,
            startTime: round1.endTime,
            endTime: round1.endTime + round2Duration,
            coolDown: coolDown2,
            maxAmountPerBuy: maxAmountPerBuy2
        });

        vm.startPrank(owner);
        bic.setPrePublicRound(round1);
        bic.setPrePublicRound(round2);
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
        address pool = bic.getUniswapV2Pair();
        pair = IUniswapV2Pair(pool);
        // Verify pool setup
        assertTrue(pair.balanceOf(owner) > 0, "Pool setup failed");
    }

    function test_simulate_swap_weth_to_bic_in_pre_public() public {
        // Set time to round1 start + 1
        uint256 currentTime = LFStartTime + 10 + 1; // round1.startTime + 1
        vm.warp(currentTime);

        // Check current LF conditions
        uint256 currentLF = bic.getCurrentLF();
        uint256 estLF = simulateLF(LFStartTime, currentTime);

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
        uint256 swapAmount = 0.001 ether;
        uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
            swapAmount,
            path
        );

        // Verify swap won't exceed max allocation and max amount per buy
        assertLe(
            user1Balance + amountOuts[1],
            maxAllocation,
            "Swap would exceed max allocation"
        );
        assertLe(
            amountOuts[1],
            maxAmountPerBuy1,
            "Swap would exceed max amount per buy"
        );

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

    function test_simulate_swap_weth_to_bic_over_max_amount_per_buy() public {
        // Set time to round1 start + 1
        uint256 currentTime = LFStartTime + 10 + 1; // round1.startTime + 1
        vm.warp(currentTime);

        // Check current LF conditions
        uint256 currentLF = bic.getCurrentLF();
        uint256 estLF = simulateLF(LFStartTime, currentTime);

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
        uint256 swapAmount = 0.1 ether;
        uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
            swapAmount,
            path
        );

        // Verify swap amount conditions
        assertLe(
            user1Balance + amountOuts[1],
            maxAllocation,
            "Total balance would exceed max allocation"
        );
        assertGe(
            amountOuts[1],
            maxAmountPerBuy1,
            "Swap amount should exceed max amount per buy"
        );

        // Execute swap and expect it to revert
        vm.startPrank(user1);
        vm.expectRevert(); // Expect the transaction to revert
        uniswapV2Router.swapExactETHForTokens{value: swapAmount}(
            0, // min amount out
            path,
            user1,
            currentTime + 60
        );
        vm.stopPrank();

        // Verify balances remained unchanged
        assertEq(
            bic.balanceOf(address(bic)),
            0,
            "BIC contract balance should be 0"
        );
        assertEq(
            bic.balanceOf(user1),
            user1Balance,
            "User1 balance should remain unchanged"
        );
    }

    function test_simulate_swap_weth_to_bic_over_max_allocation() public {
        // Set time to round1 start + 1
        uint256 currentTime = LFStartTime + 10 + 1; // round1.startTime + 1
        vm.warp(currentTime);

        // Check current LF conditions
        uint256 currentLF = bic.getCurrentLF();
        uint256 estLF = simulateLF(LFStartTime, currentTime);

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
        uint256 swapAmount = 0.001 ether;
        uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
            swapAmount,
            path
        );

        // Transfer additional tokens to push user1 balance near max allocation
        vm.startPrank(owner);
        bic.transfer(user1, maxAllocation - user1Balance - amountOuts[1] + 2);
        vm.stopPrank();

        // Verify conditions
        assertGe(
            bic.balanceOf(user1) + amountOuts[1],
            maxAllocation,
            "Total balance should exceed max allocation"
        );
        assertLe(
            amountOuts[1],
            maxAmountPerBuy1,
            "Swap amount should be within max amount per buy"
        );

        // Execute swap and expect it to revert
        vm.startPrank(user1);
        uniswapV2Router.swapExactETHForTokens{value: swapAmount}(
            0, // min amount out
            path,
            user1,
            currentTime + 60
        );
        vm.stopPrank();

        // Verify BIC contract balance
        assertEq(
            bic.balanceOf(address(bic)),
            0,
            "BIC contract balance should be 0"
        );
    }

    function test_simulate_swap_weth_to_bic_failed_by_cooldown() public {
        // Set time to round1 start + 1
        uint256 currentTime = LFStartTime + 10 + 1; // round1.startTime + 1
        vm.warp(currentTime);

        // Check current LF conditions
        uint256 currentLF = bic.getCurrentLF();
        uint256 estLF = simulateLF(LFStartTime, currentTime);

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

        // First swap setup and verification
        uint256 swapAmount = 0.001 ether;
        uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
            swapAmount,
            path
        );

        assertLe(
            user1Balance + amountOuts[1],
            maxAllocation,
            "First swap would exceed max allocation"
        );
        assertLe(
            amountOuts[1],
            maxAmountPerBuy1,
            "First swap would exceed max amount per buy"
        );

        // Execute first swap
        vm.startPrank(user1);
        uniswapV2Router.swapExactETHForTokens{value: swapAmount}(
            0, // min amount out
            path,
            user1,
            currentTime + 60
        );
        vm.stopPrank();

        // Move time forward to just before cooldown expires
        vm.warp(currentTime + coolDown1 - 1);

        // Second swap setup and verification
        uint256 swapAmount2 = 0.001 ether;
        uint256[] memory amountOuts2 = uniswapV2Router.getAmountsOut(
            swapAmount2,
            path
        );

        assertLe(
            bic.balanceOf(user1) + amountOuts2[1],
            maxAllocation,
            "Second swap would exceed max allocation"
        );
        assertLe(
            amountOuts2[1],
            maxAmountPerBuy1,
            "Second swap would exceed max amount per buy"
        );

        // Execute second swap and expect it to revert due to cooldown
        vm.startPrank(user1);
        vm.expectRevert(); // Expect the transaction to revert
        uniswapV2Router.swapExactETHForTokens{value: swapAmount2}(
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
            "BIC contract balance should be 0"
        );
        assertEq(
            bic.balanceOf(user1),
            user1Balance + amountOuts[1],
            "User1 balance should only include first swap"
        );
    }

    function test_simulate_swap_weth_to_bic_successful_after_cooldown() public {
        // Set time to round1 start + 1
        uint256 currentTime = LFStartTime + 10 + 1; // round1.startTime + 1
        vm.warp(currentTime);

        // Check current LF conditions
        uint256 currentLF = bic.getCurrentLF();
        uint256 estLF = simulateLF(LFStartTime, currentTime);

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

        // First swap setup and verification
        uint256 swapAmount = 0.001 ether;
        uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
            swapAmount,
            path
        );

        assertLe(
            user1Balance + amountOuts[1],
            maxAllocation,
            "First swap would exceed max allocation"
        );
        assertLe(
            amountOuts[1],
            maxAmountPerBuy1,
            "First swap would exceed max amount per buy"
        );

        // Execute first swap
        vm.startPrank(user1);
        uniswapV2Router.swapExactETHForTokens{value: swapAmount}(
            0, // min amount out
            path,
            user1,
            currentTime + 60
        );
        vm.stopPrank();

        // Move time forward to after cooldown expires
        vm.warp(currentTime + coolDown1);

        // Second swap setup and verification
        uint256 swapAmount2 = 0.001 ether;
        uint256[] memory amountOuts2 = uniswapV2Router.getAmountsOut(
            swapAmount2,
            path
        );

        assertLe(
            bic.balanceOf(user1) + amountOuts2[1],
            maxAllocation,
            "Second swap would exceed max allocation"
        );
        assertLe(
            amountOuts2[1],
            maxAmountPerBuy1,
            "Second swap would exceed max amount per buy"
        );

        // Execute second swap
        vm.startPrank(user1);
        uniswapV2Router.swapExactETHForTokens{value: swapAmount2}(
            0, // min amount out
            path,
            user1,
            currentTime + coolDown1 + 60
        );
        vm.stopPrank();

        // Verify final balances
        assertEq(
            bic.balanceOf(address(bic)),
            0,
            "BIC contract balance should be 0"
        );
        assertEq(
            bic.balanceOf(user1),
            user1Balance + amountOuts[1] + amountOuts2[1],
            "User1 balance should include both swaps"
        );
    }

    function test_simulate_swap_weth_to_bic_cross_rounds() public {
        // Set time to round1 start + 1
        uint256 currentTime = LFStartTime + 10 + 1; // round1.startTime + 1
        vm.warp(currentTime);

        // Check current LF conditions
        uint256 currentLF = bic.getCurrentLF();
        uint256 estLF = simulateLF(LFStartTime, currentTime);

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

        // First swap setup and verification (user1 in round1)
        uint256 swapAmount = 0.001 ether;
        uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
            swapAmount,
            path
        );

        assertLe(
            user1Balance + amountOuts[1],
            maxAllocation,
            "First swap would exceed max allocation"
        );
        assertLe(
            amountOuts[1],
            maxAmountPerBuy1,
            "First swap would exceed max amount per buy in round1"
        );

        // Execute first swap
        vm.startPrank(user1);
        uniswapV2Router.swapExactETHForTokens{value: swapAmount}(
            0, // min amount out
            path,
            user1,
            currentTime + 60
        );
        vm.stopPrank();

        // Second swap setup (user2 attempting in round1)
        uint256 swapAmount2 = 0.002 ether;
        uint256[] memory amountOuts2 = uniswapV2Router.getAmountsOut(
            swapAmount2,
            path
        );

        assertLe(
            user2Balance + amountOuts2[1],
            maxAllocation,
            "Second swap would exceed max allocation"
        );
        assertLe(
            amountOuts2[1],
            maxAmountPerBuy2,
            "Second swap would exceed max amount per buy in round2"
        );

        // Attempt user2 swap in round1 (should fail)
        vm.startPrank(user2);
        vm.expectRevert("UniswapV2: TRANSFER_FAILED");
        uniswapV2Router.swapExactETHForTokens{value: swapAmount2}(
            0,
            path,
            user2,
            currentTime + 60
        );
        vm.stopPrank();

        // Move to round2
        vm.warp(LFStartTime + 11 + round1Duration);
        // Let's add some debug logs to verify the timing
        console.log("Current time:", block.timestamp);
        console.log("Round1 start:", LFStartTime + 10);
        console.log("Round1 end:", LFStartTime + 10 + round1Duration);
        console.log("Round2 start:", LFStartTime + 10 + round1Duration);
        console.log(
            "Round2 end:",
            LFStartTime + 10 + round1Duration + round2Duration
        );
        // Attempt user1 swap in round2 (should fail)
        vm.startPrank(user1);
        vm.expectRevert("UniswapV2: TRANSFER_FAILED");
        uniswapV2Router.swapExactETHForTokens{value: swapAmount}(
            0,
            path,
            user1,
            LFStartTime + 10 + round1Duration + 60
        );
        vm.stopPrank();

        // Execute user2 swap in round2 (should succeed)
        vm.startPrank(user2);
        uniswapV2Router.swapExactETHForTokens{value: swapAmount2}(
            0,
            path,
            user2,
            LFStartTime + 10 + round1Duration + 60
        );
        vm.stopPrank();

        // Verify final balances
        assertEq(
            bic.balanceOf(address(bic)),
            0,
            "BIC contract balance should be 0"
        );
        assertEq(
            bic.balanceOf(user1),
            user1Balance + amountOuts[1],
            "User1 balance should include only round1 swap"
        );
        assertEq(
            bic.balanceOf(user2),
            user2Balance + amountOuts2[1],
            "User2 balance should include only round2 swap"
        );
    }

    function test_simulate_swap_weth_to_bic_failed_by_non_whitelisted_user()
        public
    {
        // Set time to round1 start + 1
        uint256 currentTime = LFStartTime + 10 + 1; // round1.startTime + 1
        vm.warp(currentTime);

        // Check current LF conditions
        uint256 currentLF = bic.getCurrentLF();
        uint256 estLF = simulateLF(LFStartTime, currentTime);

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
        uint256 swapAmount = 0.001 ether;
        uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
            swapAmount,
            path
        );

        // Verify user3 has no BIC tokens
        assertEq(
            bic.balanceOf(user3),
            0,
            "User3 should have no BIC tokens initially"
        );

        // Attempt swap with non-whitelisted user (should fail)
        vm.startPrank(user3);
        vm.expectRevert("UniswapV2: TRANSFER_FAILED");
        uniswapV2Router.swapExactETHForTokens{value: swapAmount}(
            0, // min amount out
            path,
            user3,
            currentTime + 60
        );
        vm.stopPrank();
    }

    function test_simulate_swap_weth_to_bic_by_owner_without_restrictions()
        public
    {
        // Transfer all owner's tokens to dead address
        vm.startPrank(owner);
        bic.transfer(address(0xdead), bic.balanceOf(owner));
        vm.stopPrank();

        // Set time to round1 start + 1
        uint256 currentTime = LFStartTime + 10 + 1; // round1.startTime + 1
        vm.warp(currentTime);

        // Check current LF conditions
        uint256 currentLF = bic.getCurrentLF();
        uint256 estLF = simulateLF(LFStartTime, currentTime);

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

        // First swap setup and verification
        uint256 swapAmount = 0.001 ether;
        uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
            swapAmount,
            path
        );

        // Verify owner has no BIC tokens initially
        assertEq(
            bic.balanceOf(owner),
            0,
            "Owner should have no BIC tokens initially"
        );

        // Execute first swap
        vm.startPrank(owner);
        uniswapV2Router.swapExactETHForTokens{value: swapAmount}(
            0, // min amount out
            path,
            owner,
            currentTime + 60
        );
        vm.stopPrank();

        // Verify balance after first swap
        assertEq(
            bic.balanceOf(owner),
            amountOuts[1],
            "Owner should have received correct amount from first swap"
        );

        // Move time forward to after cooldown
        vm.warp(currentTime + coolDown1);

        // Second swap setup with larger amount
        uint256 swapAmount2 = 0.1 ether;
        uint256[] memory amountOuts2 = uniswapV2Router.getAmountsOut(
            swapAmount2,
            path
        );

        // Execute second swap
        vm.startPrank(owner);
        uniswapV2Router.swapExactETHForTokens{value: swapAmount2}(
            0, // min amount out
            path,
            owner,
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
            bic.balanceOf(owner),
            amountOuts[1] + amountOuts2[1],
            "Owner should have received correct total amount from both swaps"
        );
    }

    function test_simulate_swap_bic_to_weth_by_non_whitelisted_user() public {
        // Transfer BIC tokens to user3
        vm.startPrank(owner);
        bic.transfer(user3, 1000 ether);
        vm.stopPrank();

        // Approve router to spend user3's BIC tokens
        vm.startPrank(user3);
        bic.approve(address(uniswapV2Router), type(uint256).max);
        vm.stopPrank();

        // Set time to round1 start + 1
        uint256 currentTime = LFStartTime + 10 + 1; // round1.startTime + 1
        vm.warp(currentTime);

        // Check current LF conditions
        uint256 currentLF = bic.getCurrentLF();
        uint256 estLF = simulateLF(LFStartTime, currentTime);

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
        uint256 swapAmount = 1000 ether;
        address[] memory sellPath = new address[](2);
        sellPath[0] = path[1]; // BIC token
        sellPath[1] = path[0]; // WETH
        uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
            swapAmount,
            sellPath
        );

        // Calculate expected fee
        uint256 fee = simulateFee(swapAmount, currentLF);

        // Verify user3 has enough tokens for the swap
        assertEq(
            bic.balanceOf(user3),
            1000 ether,
            "User3 should have correct initial BIC balance"
        );

        // Execute swap and expect it to revert
        vm.startPrank(user3);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            swapAmount,
            0, // min amount out
            sellPath,
            user3,
            currentTime + 60
        );
        vm.stopPrank();

        // Verify fees and accumulated LF
        assertEq(
            bic.balanceOf(address(bic)),
            fee,
            "BIC contract balance should equal fee"
        );
        assertEq(
            bic.balanceOf(address(bic)),
            bic.getAccumulatedLF(),
            "BIC balance should equal accumulated LF"
        );
    }
}
