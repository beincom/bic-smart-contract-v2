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

    function multicall(bytes[] calldata data) external returns (bytes[] memory) {
        return new bytes[](0);
    }
}

contract TestnetAddEditionToMarketplace is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
        address editionAddress = vm.envAddress("EDITION_ADDRESS_TESTNET");
        address marketplaceAddress = vm.envAddress("MARKETPLACE_ADDRESS_TESTNET");
        address currency = vm.envAddress("BIC_ADDRESS_TESTNET");

        BicEdition edition = BicEdition(editionAddress);
        SampleMarketplace marketplace = SampleMarketplace(marketplaceAddress);

        vm.startBroadcast(deployerPrivateKey);

        edition.setApprovalForAll(marketplaceAddress, true);

        // Prepare multicall data for 75 auctions for tokenId 3 and 5 auctions for tokenId 4
        bytes[] memory multicallData = new bytes[](80);

        // Parameters for tokenId 3
        SampleMarketplace.AuctionParameters memory paramsForId3 = SampleMarketplace.AuctionParameters({
            assetContract: editionAddress,
            tokenId: 3,
            quantity: 1,
            currency: currency,
            minimumBidAmount: 8000 ether, // Example minimum bid amount
            buyoutBidAmount: 0,
            timeBufferInSeconds: 7200, // 2 hour buffer
            bidBufferBps: 500, // 5% buffer
            startTimestamp: uint64(block.timestamp), // Start immediately
            endTimestamp: uint64(block.timestamp + 5 days) // End in 5 days
        });

        // Parameters for tokenId 4
        SampleMarketplace.AuctionParameters memory paramsForId4 = SampleMarketplace.AuctionParameters({
            assetContract: editionAddress,
            tokenId: 4,
            quantity: 1,
            currency: currency,
            minimumBidAmount: 20000 ether, // Example minimum bid amount
            buyoutBidAmount: 0,
            timeBufferInSeconds: 7200, // 2 hour buffer
            bidBufferBps: 500, // 5% buffer
            startTimestamp: uint64(block.timestamp), // Start immediately
            endTimestamp: uint64(block.timestamp + 5 days) // End in 5 days
        });

        // Encode 75 createAuction calls for tokenId 3
        for (uint256 i = 0; i < 75; i++) {
            multicallData[i] = abi.encodeWithSelector(
                SampleMarketplace.createAuction.selector,
                paramsForId3
            );
        }

        // Encode 5 createAuction calls for tokenId 4
        for (uint256 i = 0; i < 5; i++) {
            multicallData[75 + i] = abi.encodeWithSelector(
                SampleMarketplace.createAuction.selector,
                paramsForId4
            );
        }

        // Call multicall on the marketplace
        bytes[] memory results = marketplace.multicall(multicallData);

        // Log the auction creation
        for (uint256 i = 0; i < 75; i++) {
            uint256 auctionId = abi.decode(results[i], (uint256));
            console.log("Auction created for tokenId 3 with ID:", auctionId);
        }
        for (uint256 i = 75; i < 80; i++) {
            uint256 auctionId = abi.decode(results[i], (uint256));
            console.log("Auction created for tokenId 4 with ID:", auctionId);
        }

        vm.stopBroadcast();
    }
}