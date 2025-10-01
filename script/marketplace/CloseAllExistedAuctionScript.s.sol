// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";
import {stdJson} from "forge-std/StdJson.sol";

contract MarketplaceMock {
    // Mock function to simulate closing an auction
    function collectAuctionPayout(uint256 _auctionId) external {
        // Simulate auction closing logic
        console.log("Auction payout collected for:", _auctionId);
    }

    function collectAuctionTokens(uint256 _auctionId) external {
        // Simulate auction token collection logic
        console.log("Auction tokens collected for:", _auctionId);
    }
}



contract CloseAllExistedAuctionScript is Script {
    using stdJson for string;
    
    uint256 constant BATCH_SIZE = 50; // Number of calls per batch
    
    function run() external {
        console.log("Starting CloseAllExistedAuctionScript...");
        address marketplaceAddress = vm.envAddress("MARKETPLACE_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        IMulticall3 multicall = IMulticall3(0xcA11bde05977b3631167028862bE2a173976CA11); // same on both arbitrum one and arbitrum sepolia
        
        // Get auction data from JavaScript
        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "js/getUnclaimAuctionByEvents.js";
        bytes memory result = vm.ffi(inputs);
        
        // Convert bytes to string directly
        string memory jsonResult = string(result);
        console.log("Auction analysis result:");
        console.log("Full JSON result:");
        console.log(jsonResult);
        
        // Parse JSON to extract auction IDs
        uint256[] memory auctionIdsNeedToClosePayout = jsonResult.readUintArray(".auctionIdsNeedToClosePayout");
        uint256[] memory auctionIdsNeedToCloseTokens = jsonResult.readUintArray(".auctionIdsNeedToCloseTokens");
        
        console.log("Number of auctions needed to payout (tokens):", auctionIdsNeedToClosePayout.length);
        console.log("Number of auctions needed to release NFTs:", auctionIdsNeedToCloseTokens.length);
        
        // Build all Call3 arrays first
        uint256 totalCalls = auctionIdsNeedToClosePayout.length + auctionIdsNeedToCloseTokens.length;
        IMulticall3.Call3[] memory allCalls = new IMulticall3.Call3[](totalCalls);
        uint256 callIndex = 0;
        
        // Add collectAuctionPayout calls
        for (uint256 i = 0; i < auctionIdsNeedToClosePayout.length; i++) {
            allCalls[callIndex] = IMulticall3.Call3({
                target: marketplaceAddress,
                allowFailure: true,
                callData: abi.encodeWithSignature("collectAuctionPayout(uint256)", auctionIdsNeedToClosePayout[i])
            });
            callIndex++;
        }
        
        // Add collectAuctionTokens calls
        for (uint256 i = 0; i < auctionIdsNeedToCloseTokens.length; i++) {
            allCalls[callIndex] = IMulticall3.Call3({
                target: marketplaceAddress,
                allowFailure: true,
                callData: abi.encodeWithSignature("collectAuctionTokens(uint256)", auctionIdsNeedToCloseTokens[i])
            });
            callIndex++;
        }
        
        console.log("Total calls to execute:", totalCalls);
        console.log("Batch size:", BATCH_SIZE);
        
        // if (totalCalls > 0) {
        //     // Calculate number of batches
        //     uint256 numBatches = (totalCalls + BATCH_SIZE - 1) / BATCH_SIZE; // Ceiling division
        //     console.log("Number of batches:", numBatches);
            
        //     vm.startBroadcast(deployerPrivateKey);
            
        //     uint256 totalSuccessCount = 0;
        //     uint256 totalFailureCount = 0;

        //     // Execute in batches
        //     for (uint256 batchIndex = 0; batchIndex < numBatches; batchIndex++) {
        //         uint256 startIndex = batchIndex * BATCH_SIZE;
        //         uint256 endIndex = startIndex + BATCH_SIZE;
        //         if (endIndex > totalCalls) {
        //             endIndex = totalCalls;
        //         }
        //         uint256 batchSize = endIndex - startIndex;
                
        //         console.log("Executing batch", batchIndex + 1, "of", numBatches);
        //         console.log("Batch calls:", batchSize);
        //         console.log("Index range:", startIndex, "to", endIndex - 1);
                
        //         // Create batch array
        //         IMulticall3.Call3[] memory batchCalls = new IMulticall3.Call3[](batchSize);
        //         for (uint256 i = 0; i < batchSize; i++) {
        //             batchCalls[i] = allCalls[startIndex + i];
        //         }
                
        //         // Execute batch
        //         IMulticall3.Result[] memory batchResults = multicall.aggregate3(batchCalls);
                
        //         // Count results for this batch
        //         uint256 batchSuccessCount = 0;
        //         uint256 batchFailureCount = 0;
                
        //         for (uint256 i = 0; i < batchResults.length; i++) {
        //             if (batchResults[i].success) {
        //                 batchSuccessCount++;
        //             } else {
        //                 batchFailureCount++;
        //                 console.log("Call failed in batch", batchIndex + 1, "at index:", i);
        //             }
        //         }
                
        //         console.log("Batch", batchIndex + 1, "results:");
        //         console.log("Success:", batchSuccessCount, "Failed:", batchFailureCount);
                
        //         totalSuccessCount += batchSuccessCount;
        //         totalFailureCount += batchFailureCount;
        //     }
            
        //     vm.stopBroadcast();
            
        //     console.log("=== FINAL RESULTS ===");
        //     console.log("Total successful calls:", totalSuccessCount);
        //     console.log("Total failed calls:", totalFailureCount);
        //     console.log("Total calls executed:", totalSuccessCount + totalFailureCount);
        // } else {
        //     console.log("No auctions to close.");
        // }
    }
}