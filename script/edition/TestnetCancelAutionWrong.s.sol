// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

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

    function cancelAuction(
        uint256 _auctionId
    ) external {
        // Implementation of auction creation
    }

    function multicall(bytes[] calldata data) external returns (bytes[] memory) {
        return new bytes[](0);
    }
}

contract TestnetCancelAuctionWrong is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
        address marketplaceAddress = vm.envAddress("MARKETPLACE_ADDRESS_TESTNET");

        SampleMarketplace marketplace = SampleMarketplace(marketplaceAddress);

        bytes[] memory multicallData = new bytes[](5);
        uint256 startTokenId = 987;
        uint256 numberOfAuctions = 5;

        // Encode 5 cancel auction from 987 - 991 calls for tokenId 4
        for (uint256 i = 0; i < numberOfAuctions; i++) {
            multicallData[i] = abi.encodeWithSelector(
                SampleMarketplace.cancelAuction.selector,
                startTokenId + i
            );
        }

        vm.startBroadcast(deployerPrivateKey);

        marketplace.multicall(multicallData);

        vm.stopBroadcast();
    }
}