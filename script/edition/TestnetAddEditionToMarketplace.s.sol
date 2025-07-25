// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BicEdition} from "../../src/edition/BicEdition.sol";

contract SampleMarketplace {
    struct AuctionParameters {
        address assetContract;
        uint256 tokenId;
        uint256 quantity;
        address currency;
        uint256 minimumBidAmount;
        uint256 buyoutBidAmount;
        uint64 timeBufferInSeconds;
        uint64 bidBufferBps;
        uint64 startTimestamp;
        uint64 endTimestamp;
    }

    function createAuction(
        AuctionParameters calldata _params
    ) external returns (uint256 auctionId) {
        // Implementation of auction creation
        return 0; // Placeholder return value
    }
}

contract TestnetAddEditionToMarketplace is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
        address editionAddress = vm.envAddress("EDITION_ADDRESS_TESTNET");
        address marketplaceAddress = vm.envAddress("MARKETPLACE_ADDRESS_TESTNET");
        address currency = vm.envAddress("BIC_ADDRESS_TESTNET");

        BicEdition bicEdition = BicEdition(editionAddress);
        SampleMarketplace marketplace = SampleMarketplace(marketplaceAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Create an auction for the edition tokenId 3
        SampleMarketplace.AuctionParameters memory paramsForId3 = SampleMarketplace.AuctionParameters({
            assetContract: editionAddress,
            tokenId: 3, // Assuming tokenId 0 for the first lazy minted NFT
            quantity: 75,
            currency: currency,
            minimumBidAmount: 10000 ether, // Example minimum bid amount
            buyoutBidAmount: 0,
            timeBufferInSeconds: 3600, // 1 hour buffer
            bidBufferBps: 100, // 1% buffer
            startTimestamp: block.timestamp, // Start in 1 day
            endTimestamp: block.timestamp + 14 days // End in 2 days
        });
        uint256 auctionIdForId3 = marketplace.createAuction(paramsForId3);
        console.log("Auction created for tokenId 3 with ID:", auctionIdForId3);

        // Create an auction for the edition tokenId 4
        SampleMarketplace.AuctionParameters memory paramsForId4 = SampleMarketplace.AuctionParameters({
            assetContract: editionAddress,
            tokenId: 4, // Assuming tokenId 1 for the second lazy minted NFT
            quantity: 5,
            currency: currency,
            minimumBidAmount: 80000 ether, // Example minimum bid amount
            buyoutBidAmount: 0,
            timeBufferInSeconds: 3600, // 1 hour buffer
            bidBufferBps: 100, // 1% buffer
            startTimestamp: block.timestamp + 86400, // Start in 1 day
            endTimestamp: block.timestamp + 14 days + 86400 // End in 2 days
        });
        uint256 auctionIdForId4 = marketplace.createAuction(paramsForId4);
        console.log("Auction created for tokenId 4 with ID:", auctionIdForId4);

        vm.stopBroadcast();
    }
}