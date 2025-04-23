// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IPermissions} from "../../src/interfaces/IMarketplace.sol";


contract SetupAssetRolesThirdwebMarketplaceV3 is Script {
    bytes32 private constant ASSET_ROLE = keccak256("ASSET_ROLE");
    address marketplaceAddress = vm.envAddress("MARKETPLACE_ADDRESS");
    address nftOwnershipUsername = vm.envAddress("NFT_OWNERSHIP_USERNAME_COLLECTION_ADDRESS");
    address nftOwnershipCommunityName = vm.envAddress("NFT_OWNERSHIP_COMMUNITY_NAME_COLLECTION_ADDRESS"); 
    address nftOwnershipPersonalName = vm.envAddress("NFT_OWNERSHIP_PERSONAL_NAME_COLLECTION_ADDRESS");

    address nftEarningUsername = vm.envAddress("NFT_EARNING_USERNAME_COLLECTION_ADDRESS");
    address nftEarningCommunityName = vm.envAddress("NFT_EARNING_COMMUNITY_NAME_COLLECTION_ADDRESS");
    address nftEarningPersonalName = vm.envAddress("NFT_EARNING_PERSONAL_NAME_COLLECTION_ADDRESS");
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");


        vm.startBroadcast(deployerPrivateKey);
        IPermissions marketplace = IPermissions(marketplaceAddress);

        // Grant role to address(0) to restrict assets to only be listed on the marketplace
        marketplace.revokeRole(ASSET_ROLE, address(0));

        marketplace.grantRole(ASSET_ROLE, nftOwnershipUsername);
        marketplace.grantRole(ASSET_ROLE, nftOwnershipCommunityName);
        marketplace.grantRole(ASSET_ROLE, nftOwnershipPersonalName);
        marketplace.grantRole(ASSET_ROLE, nftEarningUsername);
        marketplace.grantRole(ASSET_ROLE, nftEarningCommunityName);
        marketplace.grantRole(ASSET_ROLE, nftEarningPersonalName);

        _postValidate();
        vm.stopBroadcast();
    }

    function _postValidate() internal {
        IPermissions marketplace = IPermissions(marketplaceAddress);
        require(!marketplace.hasRole(ASSET_ROLE, address(0)), "ADDRESS(0) should not have ASSET_ROLE");
        require(marketplace.hasRole(ASSET_ROLE, nftOwnershipUsername), "OWNERSHIP_USERNAME_COLLECTION_ADDRESS does not have ASSET_ROLE");
        require(marketplace.hasRole(ASSET_ROLE, nftOwnershipCommunityName), "OWNERSHIP_COMMUNITY_NAME_COLLECTION_ADDRESS does not have ASSET_ROLE");
        require(marketplace.hasRole(ASSET_ROLE, nftOwnershipPersonalName), "OWNERSHIP_PERSONAL_NAME_COLLECTION_ADDRESS does not have ASSET_ROLE");
        require(marketplace.hasRole(ASSET_ROLE, nftEarningUsername), "EARNING_USERNAME_COLLECTION_ADDRESS does not have ASSET_ROLE");
        require(marketplace.hasRole(ASSET_ROLE, nftEarningCommunityName), "EARNING_COMMUNITY_NAME_COLLECTION_ADDRESS does not have ASSET_ROLE");
        require(marketplace.hasRole(ASSET_ROLE, nftEarningPersonalName), "EARNING_PERSONAL_NAME_COLLECTION_ADDRESS does not have ASSET_ROLE");
    }
}