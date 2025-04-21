// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handles} from "../../src/namespaces/Handles.sol";
import {HandleTokenURI} from "../../src/namespaces/HandleTokenURI.sol";
import {HandlesController} from "../../src/namespaces/HandlesController.sol";
import {BicForwarder} from "../../src/forwarder/BicForwarder.sol";

contract PostSetupScript is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployOwner = vm.addr(deployerPrivateKey);
        address bicOwnerAddress = vm.envAddress("BIC_OWNER_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        // #region NFT
        Handles nftOwnershipUsername = Handles(vm.envAddress("NFT_OWNERSHIP_USERNAME_COLLECTION_ADDRESS"));
        Handles nftOwnershipCommunityName = Handles(vm.envAddress("NFT_OWNERSHIP_COMMUNITY_NAME_COLLECTION_ADDRESS")); 
        Handles nftOwnershipPersonalName = Handles(vm.envAddress("NFT_OWNERSHIP_PERSONAL_NAME_COLLECTION_ADDRESS"));

        Handles nftEarningUsername = Handles(vm.envAddress("NFT_EARNING_USERNAME_COLLECTION_ADDRESS"));
        Handles nftEarningCommunityName = Handles(vm.envAddress("NFT_EARNING_COMMUNITY_NAME_COLLECTION_ADDRESS"));
        Handles nftEarningPersonalName = Handles(vm.envAddress("NFT_EARNING_PERSONAL_NAME_COLLECTION_ADDRESS"));

        nftOwnershipUsername.setOperator(bicOwnerAddress);
        nftOwnershipCommunityName.setOperator(bicOwnerAddress);
        nftOwnershipPersonalName.setOperator(bicOwnerAddress);

        nftEarningUsername.setOperator(bicOwnerAddress);
        nftEarningCommunityName.setOperator(bicOwnerAddress);
        nftEarningPersonalName.setOperator(bicOwnerAddress);

        address controllerAddress = vm.envAddress("CONTROLLER_ADDRESS");
        address forwarder = vm.envAddress("FORWARDER_ADDRESS");

        // #region HandlesController
        HandlesController handlesController = HandlesController(controllerAddress);
        handlesController.transferOwnership(bicOwnerAddress);
        handlesController.removeOperator(deployOwner); // Remove deployer as operator(for PreMint)

        // #region BicForwarder
        BicForwarder bicForwarder = BicForwarder(forwarder);
        bicForwarder.transferOwnership(bicOwnerAddress);


        // #region HandleTokenURI
        address handleTokenURIAddress = vm.envAddress("HANDLE_TOKEN_URI_ADDRESS");
        HandleTokenURI handleTokenURI = HandleTokenURI(handleTokenURIAddress);
        handleTokenURI.transferOwnership(bicOwnerAddress);
        // #endregion

        vm.stopBroadcast();
    }
}

