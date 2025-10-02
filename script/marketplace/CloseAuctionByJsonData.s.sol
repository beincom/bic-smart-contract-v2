// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";
import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";

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

contract CloseAuctionByJsonData is Script {
    using stdJson for string;

    function run() external {
        // Path to your JSON file
        string memory path = string.concat(vm.projectRoot(), "/config/auctionsDetails.json");

        // Read the file
        string memory json = vm.readFile(path);

        uint256[] memory auctionIdsNeedToClosePayout = json.readUintArray(".auctionIdsNeedToClosePayout");
        uint256[] memory auctionIdsNeedToCloseTokens = json.readUintArray(".auctionIdsNeedToCloseTokens");

        console.log("Number of auctions needed to payout (tokens):", auctionIdsNeedToClosePayout.length);
        console.log("Number of auctions needed to release NFTs:", auctionIdsNeedToCloseTokens.length);

        console.log("Starting CloseAllExistedAuctionScript...");
        address marketplaceAddress = vm.envAddress("MARKETPLACE_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        IMulticall3 multicall = IMulticall3(0xcA11bde05977b3631167028862bE2a173976CA11); // same on both arbitrum one and arbitrum sepolia


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


         if (totalCalls > 0) {


             uint256 totalSuccessCount = 0;
             uint256 totalFailureCount = 0;

             // Calculate number of batches
             vm.startBroadcast(deployerPrivateKey);
             IMulticall3.Result[] memory batchResults = multicall.aggregate3(allCalls);
             vm.stopBroadcast();

             for (uint256 i = 0; i < batchResults.length; i++) {
                 if (batchResults[i].success) {
                     totalSuccessCount++;
                 } else {
                     totalFailureCount++;
                 }
             }


             console.log("=== FINAL RESULTS ===");
             console.log("Total successful calls:", totalSuccessCount);
             console.log("Total failed calls:", totalFailureCount);
             console.log("Total calls executed:", totalSuccessCount + totalFailureCount);
         } else {
             console.log("No auctions to close.");
         }
    }
}

