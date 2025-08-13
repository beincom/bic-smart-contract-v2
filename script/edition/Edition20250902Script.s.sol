// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BicEdition} from "../../src/edition/BicEdition.sol";
import {IClaimCondition} from "../../src/extension/interface/IClaimCondition.sol";

contract Edition20250902Script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory editionUri = vm.envString("EDITION_URI");
        address editionOwner = vm.envAddress("EDITION_OWNER");
        address auctionCreator = vm.envAddress("AUCTION_CREATOR");
        address editionTreasury = vm.envAddress("EDITION_TREASURY");

        address deployOwner = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        BicEdition bicEdition = new BicEdition(
            "In The Shadow Of Our Flag",
            "VN80",
            editionUri,
            deployOwner,
            editionTreasury
        );
        console.log("BicEdition deployed at:", address(bicEdition));

//        lazyMintNft(bicEdition);
        createDropConditions(bicEdition);
        batchMint(bicEdition, auctionCreator);
        bicEdition.transferOwnership(editionOwner);

        vm.stopBroadcast();
    }

//    function lazyMintNft(BicEdition bicEdition) internal {
//        bicEdition.lazyMint(1,"https://nft-metadata.beincom.app/collections/zXOD7foJq5mUeBEwilTeEQ/0","");
//        bicEdition.lazyMint(1,"https://nft-metadata.beincom.app/collections/zXOD7foJq5mUeBEwilTeEQ/1","");
//        bicEdition.lazyMint(1,"https://nft-metadata.beincom.app/collections/zXOD7foJq5mUeBEwilTeEQ/2","");
//        bicEdition.lazyMint(1,"https://nft-metadata.beincom.app/collections/zXOD7foJq5mUeBEwilTeEQ/3","");
//        bicEdition.lazyMint(1,"https://nft-metadata.beincom.app/collections/zXOD7foJq5mUeBEwilTeEQ/4","");
//
//    }

    function createDropConditions(
        BicEdition bicEdition
    ) internal {
        address currency = vm.envAddress("BIC_ADDRESS");
        IClaimCondition.ClaimCondition[] memory conditionsForId0 = new IClaimCondition.ClaimCondition[](1);
        conditionsForId0[0] = IClaimCondition.ClaimCondition({
            startTimestamp: block.timestamp,
            maxClaimableSupply: 5000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 99,
            merkleRoot: bytes32(0),
            pricePerToken: 250 ether,
            currency: currency,
            metadata: ""
        });
        bicEdition.setClaimConditions(
            0,
            conditionsForId0,
            false
        );
        IClaimCondition.ClaimCondition[] memory conditionsForId1 = new IClaimCondition.ClaimCondition[](1);
        conditionsForId1[0] = IClaimCondition.ClaimCondition({
            startTimestamp: block.timestamp,
            maxClaimableSupply: 1200,
            supplyClaimed: 0,
            quantityLimitPerWallet: 99,
            merkleRoot: bytes32(0),
            pricePerToken: 1800 ether,
            currency: currency,
            metadata: ""
        });
        bicEdition.setClaimConditions(
            1,
            conditionsForId1,
            false
        );
        IClaimCondition.ClaimCondition[] memory conditionsForId2 = new IClaimCondition.ClaimCondition[](1);
        conditionsForId2[0] = IClaimCondition.ClaimCondition({
            startTimestamp: block.timestamp,
            maxClaimableSupply: 350,
            supplyClaimed: 0,
            quantityLimitPerWallet: 99,
            merkleRoot: bytes32(0),
            pricePerToken: 3000 ether,
            currency: currency,
            metadata: ""
        });
        bicEdition.setClaimConditions(
            2,
            conditionsForId2,
            false
        );
    }

    function batchMint(BicEdition bicEdition, address receipt) internal {
        uint256 numberOfTokensId3 = vm.envUint("EDITION_AUCTION_NUMBER_OF_TOKENS_ID_3");
        uint256 numberOfTokensId4 = vm.envUint("EDITION_AUCTION_NUMBER_OF_TOKENS_ID_4");
        uint256[] memory ids = new uint256[](2);
        ids[0] = 3;
        ids[1] = 4;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = numberOfTokensId3;
        amounts[1] = numberOfTokensId4;
        bicEdition.ownerMintBatch(receipt, ids, amounts);
    }
}