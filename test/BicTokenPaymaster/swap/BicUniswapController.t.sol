//// SPDX-License-Identifier: MIT
//pragma solidity ^0.8.23;
//
//import {BicStorage} from "../../../src/storage/BicStorage.sol";
//import "../BicTokenPaymasterTestBase.sol";
//import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
//
//contract BicUniswapController is BicTokenPaymasterTestBase {
//    // Constants
//    uint256 constant INIT_BIC_AMOUNT = 500000000 * 1e18;
//    uint256 constant INIT_ETH_AMOUNT = 100 ether;
//    // Pre-public round info
//    uint256 round1Duration = 100;
//    uint256 round2Duration = 200;
//    uint256 coolDown1 = 5;
//    uint256 maxAmountPerBuy1 = 10000 * 1e18;
//    uint256 coolDown2 = 10;
//    uint256 maxAmountPerBuy2 = 20000 * 1e18;
//
//    // Liquidity fee info
//    uint256 maxAllocation = 50000000 * 1e18;
//    uint256 minSwapBackAndLiquify = 500000 * 1e18;
//    uint256 maxLF = 1500;
//    uint256 minLF = 300;
//    uint256 LFReduction = 50;
//    uint256 LFPeriod = 30 days;
//    uint256 user1Balance = 5000000 * 1e18;
//    uint256 user2Balance = 5000000 * 1e18;
//
//    // Test addresses
//    address user1 = address(0x2);
//    address user2 = address(0x3);
//    address user3 = address(0x4);
//
//    // Get LFStartTime
//    uint256 LFStartTime = block.timestamp;
//
//    // Pool variables
//    IUniswapV2Pair pair;
//    address[] path;
//
//    function simulateLF(
//        uint256 startTime,
//        uint256 currentTime
//    ) internal view returns (uint256) {
//        uint256 totalReduction = ((currentTime - startTime) * LFReduction) /
//            LFPeriod;
//
//        if (totalReduction + minLF >= maxLF) {
//            return minLF;
//        } else {
//            return maxLF - totalReduction;
//        }
//    }
//
//    function simulateFee(
//        uint256 amount,
//        uint256 currentLF
//    ) internal pure returns (uint256) {
//        return (amount * currentLF) / 10000;
//    }
//
//    // Constants
//    function setUp() public virtual override {
//        super.setUp();
//
//        // 1. First ensure owner has both ETH and BIC
//        vm.deal(owner, 1000 ether);
//        vm.deal(user1, 10 ether);
//        vm.deal(user2, 10 ether);
//        vm.deal(user3, 10 ether);
//
//        // Debug balances
//        console.log("Owner BIC balance:", bic.balanceOf(owner));
//        console.log("Owner ETH balance:", owner.balance);
//
//        vm.startPrank(owner);
//
//        // 2. Make sure the pair exists
//        address pairAddress = getUniswapV2Pair();
//        console.log("Pair address:", pairAddress);
//
//        // 3. Clear any existing approvals first
//        bic.approve(address(uniswapV2Router), 0);
//
//        // 4. Approve new amount
//        bic.approve(address(uniswapV2Router), type(uint256).max);
//        console.log(
//            "Router approval:",
//            bic.allowance(owner, address(uniswapV2Router))
//        );
//
//        // Get reserves before
//        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pairAddress)
//            .getReserves();
//        console.log("Reserves before - BIC:", reserve0, "WETH:", reserve1);
//
//        // 5. Add liquidity with more detailed error handling
//        try
//            uniswapV2Router.addLiquidityETH{value: INIT_ETH_AMOUNT}(
//                address(bic),
//                INIT_BIC_AMOUNT,
//                0,
//                0,
//                owner,
//                block.timestamp + 100
//            )
//        returns (uint amountToken, uint amountETH, uint liquidity) {
//            console.log("Liquidity added successfully");
//            console.log("BIC added:", amountToken);
//            console.log("ETH added:", amountETH);
//            console.log("LP tokens received:", liquidity);
//        } catch Error(string memory reason) {
//            console.log("Failed to add liquidity:", reason);
//        } catch (bytes memory returnData) {
//            console.log("Failed with raw error");
//            console.logBytes(returnData);
//        }
//
//        vm.stopPrank();
//
//        // Verify final state
//        pair = IUniswapV2Pair(pairAddress);
//        (reserve0, reserve1, ) = pair.getReserves();
//        console.log("Reserves after - BIC:", reserve0, "WETH:", reserve1);
//        console.log("LP tokens owned by owner:", pair.balanceOf(owner));
//
//        // Setup pre-public whitelist
//        address[] memory addresses = new address[](2);
//        addresses[0] = user1;
//        addresses[1] = user2;
//        uint256[] memory categories = new uint256[](2);
//        categories[0] = 1;
//        categories[1] = 2;
//
//        vm.startPrank(owner);
//        // Transfer initial balances
//        bic.transfer(user1, user1Balance);
//        bic.transfer(user2, user2Balance);
//        console.log("bic of owner", bic.balanceOf(owner));
//        console.log("eth of owner", owner.balance);
//
//        // Mint WETH to users
//        deal(address(weth), user1, 100 ether);
//        deal(address(weth), user2, 100 ether);
//
//        // Ensure owner has enough tokens
//        assertGe(
//            bic.balanceOf(owner),
//            INIT_BIC_AMOUNT,
//            "Owner doesn't have enough tokens"
//        );
//
//        // Check ETH balance
//        assertGe(
//            owner.balance,
//            INIT_ETH_AMOUNT,
//            "Owner doesn't have enough ETH"
//        );
//
//        // Setup path and pair
//        path = new address[](2);
//        path[0] = address(weth);
//        path[1] = address(bic);
//        // Get the pool address and create pair interface
//        address pool = getUniswapV2Pair();
//        pair = IUniswapV2Pair(pool);
//        // Verify pool setup
//        assertTrue(pair.balanceOf(owner) > 0, "Pool setup failed");
//    }
//
//    // function test_simulate_controller_swap_back_and_liquify_in_public() public {
//    //     // Set time to LFStartTime + 2 periods + 1
//    //     uint256 currentTime = LFStartTime + (LFPeriod * 2) + 1;
//    //     vm.warp(currentTime);
//
//    //     // Disable pre-public
//    //     vm.startPrank(owner);
//    //     vm.stopPrank();
//
//    //     // Approve router for user1
//    //     vm.startPrank(user1);
//    //     bic.approve(address(uniswapV2Router), type(uint256).max);
//    //     vm.stopPrank();
//
//    //     // Check current LF conditions
//    //     uint256 currentLF = bic.getCurrentLF();
//    //     uint256 estLF = simulateLF(LFStartTime, currentTime);
//
//    //     assertEq(currentLF, estLF, "Current LF should match estimated LF");
//    //     assertLe(
//    //         currentLF,
//    //         maxLF,
//    //         "Current LF should be less than or equal to maxLF"
//    //     );
//    //     assertGe(
//    //         currentLF,
//    //         minLF,
//    //         "Current LF should be greater than or equal to minLF"
//    //     );
//
//    //     // Setup first swap parameters
//    //     uint256 swapAmount = maxAllocation / 10;
//    //     address[] memory sellPath = new address[](2);
//    //     sellPath[0] = path[1]; // BIC token
//    //     sellPath[1] = path[0]; // WETH
//    //     uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
//    //         swapAmount,
//    //         sellPath
//    //     );
//
//    //     // Calculate and verify fee
//    //     uint256 fee = simulateFee(swapAmount, currentLF);
//    //     assertGe(
//    //         fee,
//    //         minSwapBackAndLiquify,
//    //         "Fee should be >= minSwapBackAndLiquify"
//    //     );
//
//    //     // Execute first swap
//    //     vm.startPrank(user1);
//    //     uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
//    //         swapAmount,
//    //         0, // min amount out
//    //         sellPath,
//    //         user1,
//    //         currentTime + 60
//    //     );
//    //     vm.stopPrank();
//
//    //     // Verify accumulated LF
//    //     uint256 accumulatedLF = bic.balanceOf(address(bic));
//    //     assertGe(
//    //         accumulatedLF,
//    //         minSwapBackAndLiquify,
//    //         "Accumulated LF should be >= minSwapBackAndLiquify"
//    //     );
//
//    //     // Disable swap back and liquify
//    //     vm.startPrank(owner);
//    //     bic.setSwapBackEnabled(false);
//    //     vm.stopPrank();
//
//    //     // Setup second swap
//    //     vm.startPrank(user2);
//    //     bic.approve(address(uniswapV2Router), type(uint256).max);
//    //     uint256 swapAmount2 = maxAllocation / 10;
//    //     uint256 fee2 = simulateFee(swapAmount2, currentLF);
//
//    //     // Execute second swap
//    //     uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
//    //         swapAmount2,
//    //         0, // min amount out
//    //         sellPath,
//    //         user1,
//    //         currentTime + 60
//    //     );
//    //     vm.stopPrank();
//
//    //     // Verify accumulated LF after swap back
//    //     uint256 accumulatedLFAfterSwapBack = bic.balanceOf(address(bic));
//    //     assertEq(
//    //         accumulatedLFAfterSwapBack,
//    //         fee + fee2,
//    //         "Accumulated LF should equal sum of fees"
//    //     );
//
//    //     // Withdraw stuck tokens
//    //     vm.prank(owner);
//    //     bic.withdrawStuckToken(address(bic), user3, accumulatedLFAfterSwapBack);
//
//    //     // Verify final balance
//    //     assertEq(
//    //         bic.balanceOf(user3),
//    //         accumulatedLFAfterSwapBack,
//    //         "User3 should receive all accumulated fees"
//    //     );
//    // }
//
//    // function test_simulate_renounce_controller_swap_back_and_liquify_in_public()
//    //     public
//    // {
//    //     // Set time to LFStartTime + 2 periods + 1
//    //     uint256 currentTime = LFStartTime + (LFPeriod * 2) + 1;
//    //     vm.warp(currentTime);
//
//    //     // Disable pre-public
//    //     vm.startPrank(owner);
//    //     vm.stopPrank();
//    //     // Approve router for user1
//    //     vm.startPrank(user1);
//    //     bic.approve(address(uniswapV2Router), type(uint256).max);
//    //     vm.stopPrank();
//
//    //     // Check current LF conditions
//    //     uint256 currentLF = bic.getCurrentLF();
//    //     uint256 estLF = simulateLF(LFStartTime, currentTime);
//
//    //     assertEq(currentLF, estLF, "Current LF should match estimated LF");
//    //     assertLe(
//    //         currentLF,
//    //         maxLF,
//    //         "Current LF should be less than or equal to maxLF"
//    //     );
//    //     assertGe(
//    //         currentLF,
//    //         minLF,
//    //         "Current LF should be greater than or equal to minLF"
//    //     );
//
//    //     // Setup first swap parameters
//    //     uint256 swapAmount = maxAllocation / 10;
//    //     address[] memory sellPath = new address[](2);
//    //     sellPath[0] = path[1]; // BIC token
//    //     sellPath[1] = path[0]; // WETH
//
//    //     // Calculate and verify fee
//    //     uint256 fee = simulateFee(swapAmount, currentLF);
//    //     assertGe(
//    //         fee,
//    //         minSwapBackAndLiquify,
//    //         "Fee should be >= minSwapBackAndLiquify"
//    //     );
//
//    //     // Execute first swap
//    //     vm.startPrank(user1);
//    //     uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
//    //         swapAmount,
//    //         0, // min amount out
//    //         sellPath,
//    //         user1,
//    //         currentTime + 60
//    //     );
//    //     vm.stopPrank();
//
//    //     // Verify accumulated LF
//    //     uint256 accumulatedLF = bic.balanceOf(address(bic));
//    //     assertGe(
//    //         accumulatedLF,
//    //         minSwapBackAndLiquify,
//    //         "Accumulated LF should be >= minSwapBackAndLiquify"
//    //     );
//
//    //     // Renounce liquidity fee controller
//    //     vm.startPrank(owner);
//    //     vm.stopPrank();
//    //     // Attempt to set swap back enabled (should revert)
//    //     vm.startPrank(owner);
//    //     vm.expectRevert();
//    //     bic.setSwapBackEnabled(false);
//    //     vm.stopPrank();
//    //     // Setup second swap
//    //     vm.startPrank(user2);
//    //     bic.approve(address(uniswapV2Router), type(uint256).max);
//    //     uint256 swapAmount2 = maxAllocation / 10;
//    //     uint256 fee2 = simulateFee(swapAmount2, currentLF);
//
//    //     // Execute second swap
//    //     uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
//    //         swapAmount2,
//    //         0, // min amount out
//    //         sellPath,
//    //         user1,
//    //         currentTime + 60
//    //     );
//    //     vm.stopPrank();
//
//    //     // Verify accumulated LF after swap back
//    //     uint256 accumulatedLFAfterSwapBack = bic.balanceOf(address(bic));
//    //     assertLe(
//    //         accumulatedLFAfterSwapBack,
//    //         fee + fee2,
//    //         "Accumulated LF should be <= sum of fees"
//    //     );
//
//    //     // Withdraw stuck tokens
//    //     vm.prank(owner);
//    //     bic.withdrawStuckToken(address(bic), user3, accumulatedLFAfterSwapBack);
//
//    //     // Verify final balance
//    //     assertEq(
//    //         bic.balanceOf(user3),
//    //         accumulatedLFAfterSwapBack,
//    //         "User3 should receive all accumulated fees"
//    //     );
//    // }
//
//    // function test_simulate_controller_swap_weth_to_bic_cross_rounds() public {
//    //     // Set time to round1 start + 1
//    //     uint256 currentTime = LFStartTime + 10 + 1; // round1.startTime + 1
//    //     vm.warp(currentTime);
//
//    //     // Check current LF conditions
//    //     uint256 currentLF = bic.getCurrentLF();
//    //     uint256 estLF = simulateLF(LFStartTime, currentTime);
//
//    //     assertEq(currentLF, estLF, "Current LF should match estimated LF");
//    //     assertLe(
//    //         currentLF,
//    //         maxLF,
//    //         "Current LF should be less than or equal to maxLF"
//    //     );
//    //     assertGe(
//    //         currentLF,
//    //         minLF,
//    //         "Current LF should be greater than or equal to minLF"
//    //     );
//
//    //     // First swap setup and verification (user1 in round1)
//    //     uint256 swapAmount = 0.001 ether;
//    //     uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
//    //         swapAmount,
//    //         path
//    //     );
//
//    //     assertLe(
//    //         user1Balance + amountOuts[1],
//    //         maxAllocation,
//    //         "First swap would exceed max allocation"
//    //     );
//    //     assertLe(
//    //         amountOuts[1],
//    //         maxAmountPerBuy1,
//    //         "First swap would exceed max amount per buy in round1"
//    //     );
//
//    //     // Execute first swap
//    //     vm.startPrank(user1);
//    //     uniswapV2Router.swapExactETHForTokens{value: swapAmount}(
//    //         0, // min amount out
//    //         path,
//    //         user1,
//    //         currentTime + 60
//    //     );
//    //     vm.stopPrank();
//
//    //     // Second swap setup (user2 attempting in round1)
//    //     uint256 swapAmount2 = 0.002 ether;
//    //     uint256[] memory amountOuts2 = uniswapV2Router.getAmountsOut(
//    //         swapAmount2,
//    //         path
//    //     );
//
//    //     assertLe(
//    //         user2Balance + amountOuts2[1],
//    //         maxAllocation,
//    //         "Second swap would exceed max allocation"
//    //     );
//    //     assertLe(
//    //         amountOuts2[1],
//    //         maxAmountPerBuy2,
//    //         "Second swap would exceed max amount per buy in round2"
//    //     );
//
//    //     // Attempt user2 swap in round1 (should fail)
//    //     vm.startPrank(user2);
//    //     vm.expectRevert("UniswapV2: TRANSFER_FAILED");
//    //     uniswapV2Router.swapExactETHForTokens{value: swapAmount2}(
//    //         0,
//    //         path,
//    //         user2,
//    //         currentTime + 60
//    //     );
//    //     vm.stopPrank();
//
//    //     // Update whitelist for user2
//    //     address[] memory addresses = new address[](1);
//    //     addresses[0] = user2;
//    //     uint256[] memory categories = new uint256[](1);
//    //     categories[0] = 1;
//
//    //     vm.prank(owner);
//    //     bic.setPrePublicWhitelist(addresses, categories);
//
//    //     // Move to round2
//    //     vm.warp(LFStartTime + 10 + round1Duration);
//    //     // Let's add some debug logs to verify the timing
//    //     console.log("Current time:", block.timestamp);
//    //     console.log("Round1 start:", LFStartTime + 10);
//    //     console.log("Round1 end:", LFStartTime + 10 + round1Duration);
//    //     console.log("Round2 start:", LFStartTime + 10 + round1Duration);
//    //     console.log(
//    //         "Round2 end:",
//    //         LFStartTime + 10 + round1Duration + round2Duration
//    //     );
//
//    //     // Execute user2 swap in round2
//    //     vm.startPrank(user2);
//    //     uniswapV2Router.swapExactETHForTokens{value: swapAmount2}(
//    //         0,
//    //         path,
//    //         user2,
//    //         LFStartTime + 10 + round1Duration + 60
//    //     );
//    //     vm.stopPrank();
//
//    //     // Verify final balances
//    //     assertEq(
//    //         bic.balanceOf(address(bic)),
//    //         0,
//    //         "BIC contract balance should be 0"
//    //     );
//    //     assertEq(
//    //         bic.balanceOf(user1),
//    //         user1Balance + amountOuts[1],
//    //         "User1 balance should include only round1 swap"
//    //     );
//    //     assertEq(
//    //         bic.balanceOf(user2),
//    //         user2Balance + amountOuts2[1],
//    //         "User2 balance should include only round2 swap"
//    //     );
//    // }
//
//    // function test_simulate_renounce_controller_swap_weth_to_bic_cross_rounds()
//    //     public
//    // {
//    //     // Set time to round1 start + 1
//    //     uint256 currentTime = LFStartTime + 10 + 1; // round1.startTime + 1
//    //     vm.warp(currentTime);
//
//    //     // Check current LF conditions
//    //     uint256 currentLF = bic.getCurrentLF();
//    //     uint256 estLF = simulateLF(LFStartTime, currentTime);
//
//    //     assertEq(currentLF, estLF, "Current LF should match estimated LF");
//    //     assertLe(
//    //         currentLF,
//    //         maxLF,
//    //         "Current LF should be less than or equal to maxLF"
//    //     );
//    //     assertGe(
//    //         currentLF,
//    //         minLF,
//    //         "Current LF should be greater than or equal to minLF"
//    //     );
//
//    //     // First swap setup and verification (user1 in round1)
//    //     uint256 swapAmount = 0.001 ether;
//    //     uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
//    //         swapAmount,
//    //         path
//    //     );
//
//    //     assertLe(
//    //         user1Balance + amountOuts[1],
//    //         maxAllocation,
//    //         "First swap would exceed max allocation"
//    //     );
//    //     assertLe(
//    //         amountOuts[1],
//    //         maxAmountPerBuy1,
//    //         "First swap would exceed max amount per buy in round1"
//    //     );
//
//    //     // Execute first swap
//    //     vm.startPrank(user1);
//    //     uniswapV2Router.swapExactETHForTokens{value: swapAmount}(
//    //         0, // min amount out
//    //         path,
//    //         user1,
//    //         currentTime + 60
//    //     );
//    //     vm.stopPrank();
//
//    //     // Second swap setup (user2 attempting in round1)
//    //     uint256 swapAmount2 = 0.002 ether;
//    //     uint256[] memory amountOuts2 = uniswapV2Router.getAmountsOut(
//    //         swapAmount2,
//    //         path
//    //     );
//
//    //     assertLe(
//    //         user2Balance + amountOuts2[1],
//    //         maxAllocation,
//    //         "Second swap would exceed max allocation"
//    //     );
//    //     assertLe(
//    //         amountOuts2[1],
//    //         maxAmountPerBuy2,
//    //         "Second swap would exceed max amount per buy in round2"
//    //     );
//
//    //     // Attempt user2 swap in round1 (should fail)
//    //     vm.startPrank(user2);
//    //     vm.expectRevert("UniswapV2: TRANSFER_FAILED");
//    //     uniswapV2Router.swapExactETHForTokens{value: swapAmount2}(
//    //         0,
//    //         path,
//    //         user2,
//    //         currentTime + 60
//    //     );
//    //     vm.stopPrank();
//
//    //     // Update whitelist for user2
//    //     address[] memory addresses = new address[](1);
//    //     addresses[0] = user2;
//    //     uint256[] memory categories = new uint256[](1);
//    //     categories[0] = 1;
//
//    //     vm.startPrank(owner);
//    //     bic.setPrePublicWhitelist(addresses, categories);
//    //     bic.renounceOperator(); // Renounce pre-public control
//    //     vm.stopPrank();
//
//    //     // Execute user2 swap after renouncing
//    //     vm.startPrank(user2);
//    //     uniswapV2Router.swapExactETHForTokens{value: swapAmount2}(
//    //         0,
//    //         path,
//    //         user2,
//    //         LFStartTime + 10 + 60
//    //     );
//    //     vm.stopPrank();
//
//    //     // Verify final balances
//    //     assertEq(
//    //         bic.balanceOf(address(bic)),
//    //         0,
//    //         "BIC contract balance should be 0"
//    //     );
//    //     assertEq(
//    //         bic.balanceOf(user1),
//    //         user1Balance + amountOuts[1],
//    //         "User1 balance should include only first swap"
//    //     );
//    //     assertEq(
//    //         bic.balanceOf(user2),
//    //         user2Balance + amountOuts2[1],
//    //         "User2 balance should include only second swap"
//    //     );
//    // }
//
//    // function test_simulate_pause_transaction_except_excluded_addresses()
//    //     public
//    // {
//    //     // Renounce pre-public and pause transactions
//    //     vm.startPrank(owner);
//    //     bic.setPrePublic(false);
//    //     bic.renounceOperator();
//    //     bic.pause();
//    //     vm.stopPrank();
//
//    //     // Test transfers from non-excluded addresses (should fail)
//    //     vm.startPrank(user1);
//    //     vm.expectRevert();
//    //     bic.transfer(user2, user1Balance);
//    //     vm.stopPrank();
//
//    //     // Test transfers from owner (excluded by default)
//    //     vm.startPrank(owner);
//    //     bic.transfer(user1, user1Balance);
//
//    //     // Set user2 as excluded
//    //     bic.setIsExcluded(user1, true);
//    //     vm.stopPrank();
//
//    //     // Test transfer from newly excluded user2
//    //     vm.prank(user1);
//    //     bic.transfer(user2, user1Balance * 2);
//
//    //     // Verify final balances
//    //     assertEq(
//    //         bic.balanceOf(user2),
//    //         user2Balance * 3,
//    //         "User2 should have triple their initial balance"
//    //     );
//    //     assertEq(bic.balanceOf(user1), 0, "User1 should have zero balance");
//    // }
//}
