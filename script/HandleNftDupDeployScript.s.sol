// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {DupHandles} from "../src/namespaces/DupHandles.sol";
import {HandleTokenURI} from "../src/namespaces/HandleTokenURI.sol";
contract HandleNftDupDeployScript is Script {
    struct NFTData {
        string namespace;
        string name;
        string symbol;
        string imageDescription;
        string imageUri;
    }
    
    NFTData nftData = NFTData({
        namespace: "poNFT",
        name: "Profile Ownership NFT",
        symbol: "poNFT",
        imageDescription: "Beincom - Profile Ownership NFT@",
        imageUri: "https://api.beincom.io/v1/wallet/uri/opnft"
    });

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployOwner = vm.addr(deployerPrivateKey);
        address handleTokenURIAddress = vm.envAddress("HANDLE_TOKEN_URI_ADDRESS");
        address controllerAddress = vm.envAddress("CONTROLLER_ADDRESS");
        vm.startBroadcast(deployerPrivateKey);

        DupHandles dupHandles = new DupHandles();
        dupHandles.initialize(nftData.namespace, nftData.name, nftData.symbol, deployOwner);
        dupHandles.setHandleTokenURIContract(handleTokenURIAddress);
        dupHandles.setController(controllerAddress);

        HandleTokenURI handleTokenURI = HandleTokenURI(handleTokenURIAddress);
        handleTokenURI.setNameElement(nftData.namespace, nftData.imageDescription, nftData.imageUri);

        vm.stopBroadcast();
        console.log("DupHandles deployed at", address(dupHandles));
        console.log("Deployer", deployOwner);
    }
}

