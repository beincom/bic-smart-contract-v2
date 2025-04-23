// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handles} from "../../src/namespaces/Handles.sol";
import {HandleTokenURI} from "../../src/namespaces/HandleTokenURI.sol";
import {HandlesController} from "../../src/namespaces/HandlesController.sol";
import {BicForwarder} from "../../src/forwarder/BicForwarder.sol";
import {IPermissions} from "../../src/interfaces/IMarketplace.sol";


contract PostSetupNFTScript is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
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

        require(nftOwnershipUsername.OPERATOR() == bicOwnerAddress, "NFT_OWNERSHIP_USERNAME_COLLECTION_ADDRESS operator is not BIC_OWNER_ADDRESS");
        require(nftOwnershipCommunityName.OPERATOR() == bicOwnerAddress, "NFT_OWNERSHIP_COMMUNITY_NAME_COLLECTION_ADDRESS operator is not BIC_OWNER_ADDRESS");
        require(nftOwnershipPersonalName.OPERATOR() == bicOwnerAddress, "NFT_OWNERSHIP_PERSONAL_NAME_COLLECTION_ADDRESS operator is not BIC_OWNER_ADDRESS");

        require(nftEarningUsername.OPERATOR() == bicOwnerAddress, "NFT_EARNING_USERNAME_COLLECTION_ADDRESS operator is not BIC_OWNER_ADDRESS");
        require(nftEarningCommunityName.OPERATOR() == bicOwnerAddress, "NFT_EARNING_COMMUNITY_NAME_COLLECTION_ADDRESS operator is not BIC_OWNER_ADDRESS");
        require(nftEarningPersonalName.OPERATOR() == bicOwnerAddress, "NFT_EARNING_PERSONAL_NAME_COLLECTION_ADDRESS operator is not BIC_OWNER_ADDRESS");

        // #region HandleTokenURI
        address handleTokenURIAddress = vm.envAddress("HANDLE_TOKEN_URI_ADDRESS");
        HandleTokenURI handleTokenURI = HandleTokenURI(handleTokenURIAddress);
        handleTokenURI.transferOwnership(bicOwnerAddress);
        require(handleTokenURI.owner() == bicOwnerAddress, "HandleTokenURI owner is not BIC_OWNER_ADDRESS");
        // #endregion


        vm.stopBroadcast();
    }
}

contract PostSetupForwarderScript is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address bicOwnerAddress = vm.envAddress("BIC_OWNER_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        address forwarder = vm.envAddress("FORWARDER_ADDRESS");
        // #region BicForwarder
        BicForwarder bicForwarder = BicForwarder(forwarder);
        bicForwarder.transferOwnership(bicOwnerAddress);

        require(bicForwarder.owner() == bicOwnerAddress, "BicForwarder owner is not BIC_OWNER_ADDRESS");
        // #endregion
        vm.stopBroadcast();
    }
}

contract PostSetupHandleControllerScript is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployOwner = vm.addr(deployerPrivateKey);
        address bicOwnerAddress = vm.envAddress("BIC_OWNER_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        address controllerAddress = vm.envAddress("CONTROLLER_ADDRESS");

        // #region HandlesController
        HandlesController handlesController = HandlesController(controllerAddress);
        handlesController.removeOperator(deployOwner); // Remove deployer as operator(for PreMint)
        handlesController.transferOwnership(bicOwnerAddress);

        require(handlesController.owner() == bicOwnerAddress, "HandlesController owner is not BIC_OWNER_ADDRESS");
        address[] memory operators = handlesController.getOperators();
        
        require(operators.length == 1, "HandlesController has more than 1 operator");
        require(operators[0] == bicOwnerAddress, "HandlesController operator is not BIC_OWNER_ADDRESS");

        vm.stopBroadcast();
    }
}

contract PostSetupMarketplaceScript is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployOwner = vm.addr(deployerPrivateKey);
        address marketplaceAddress = vm.envAddress("MARKETPLACE_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        IPermissions marketplace = IPermissions(marketplaceAddress);
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;

        // Revoke admin role for deployer
        marketplace.revokeRole(DEFAULT_ADMIN_ROLE, deployOwner);
        require(!marketplace.hasRole(DEFAULT_ADMIN_ROLE, deployOwner), "Deployer still has DEFAULT_ADMIN_ROLE");

        vm.stopBroadcast();
    }
}

