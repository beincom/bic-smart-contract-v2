// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Handles} from "../src/namespaces/Handles.sol";
import {HandleTokenURI} from "../src/namespaces/HandleTokenURI.sol";

contract SampleBicFactory {
    function deployProxyByImplementation(
        address _implementation,
        bytes memory _data,
        bytes32 _salt
    ) public returns (address deployedProxy) {
        // Deploy the proxy
    }
}

contract HandleNftDeployScript is Script {
    struct NFTData {
        string namespace;
        string name;
        string symbol;
        string imageDescription;
        string imageUri;
    }

    NFTData[] nftDataList = [
        NFTData({
            namespace: "uoNFT",
            name: "Username Ownership NFT",
            symbol: "uoNFT", 
            imageDescription: "Beincom - Username Ownership NFT@",
            imageUri: "https://media.beincom.app/image/uri/ounft"
        }),
        NFTData({
            namespace: "coNFT",
            name: "Community Ownership NFT",
            symbol: "coNFT",
            imageDescription: "Beincom - Community Ownership NFT@",
            imageUri: "https://media.beincom.app/image/uri/ocnft"
        }),
        NFTData({
            namespace: "ubNFT",
            name: "Username Base NFT",
            symbol: "ubNFT",
            imageDescription: "Beincom - Username Base NFT@",
            imageUri: "https://media.beincom.app/image/uri/eunft"
        }),
        NFTData({
            namespace: "cbNFT",
            name: "Community Base NFT",
            symbol: "cbNFT",
            imageDescription: "Beincom - Community Base NFT@",
            imageUri: "https://media.beincom.app/image/uri/ecnft"
        }),
        NFTData({
            namespace: "pbNFT",
            name: "Profile Base NFT",
            symbol: "pbNFT",
            imageDescription: "Beincom - Profile Base NFT@",
            imageUri: "https://media.beincom.app/image/uri/epnft"
        })
    ];


    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address bicFactoryAddress = vm.envAddress("BIC_FACTORY_ADDRESS");
        address handlesAddress = vm.envAddress("HANDLES_ADDRESS"); 
        address handleTokenURIAddress = vm.envAddress("HANDLE_TOKEN_URI_ADDRESS");
        address controllerAddress = vm.envAddress("CONTROLLER_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        SampleBicFactory bicFactory = SampleBicFactory(bicFactoryAddress);
        Handles handles = Handles(handlesAddress);
        HandleTokenURI handleTokenURI = HandleTokenURI(handleTokenURIAddress);

        for (uint i = 0; i < nftDataList.length; i++) {
            NFTData memory nft = nftDataList[i];
            console.log("Clone handle for namespace: ", nft.namespace);

            bytes memory initData = abi.encodeWithSignature(
                "initialize(string,string,string,address)",
                nft.namespace,
                nft.name,
                nft.symbol,
                vm.addr(deployerPrivateKey)
            );

            bytes32 salt = keccak256(
                abi.encodePacked("Handles", nft.namespace, uint256(0))
            );

            console.log("Deploying proxy for namespace: ", nft.namespace);

            address cloneAddress = bicFactory.deployProxyByImplementation(
                address(handles),
                initData,
                salt
            );

            console.log("cloneAddress: ", cloneAddress);
            
            Handles clone = Handles(cloneAddress);
            clone.setHandleTokenURIContract(address(handleTokenURI));
            clone.setController(controllerAddress);
            handleTokenURI.setNameElement(nft.namespace, nft.imageDescription, nft.imageUri);
        }

        vm.stopBroadcast();
    }
}
