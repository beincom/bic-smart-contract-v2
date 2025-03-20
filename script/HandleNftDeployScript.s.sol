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
            namespace: "poNFT",
            name: "Profile Ownership NFT",
            symbol: "poNFT",
            imageDescription: "Beincom - Profile Ownership NFT@",
            imageUri: "https://api.beincom.io/v1/wallet/uri/opnft"
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


contract NftConfigScript is Script {
    struct NFTData {
        string namespace;
        string name;
        string symbol;
        string imageDescription;
        string imageUri;
        address nftAddress;
    }

    NFTData[] nftDataList = [
        NFTData({
            namespace: "uoNFT",
            name: "Username Ownership NFT",
            symbol: "uoNFT", 
            imageDescription: "Beincom - Username Ownership NFT@",
            imageUri: "https://media.beincom.app/image/uri/ounft",
            nftAddress: 0x28F5452907408199c3b8683D2752414B5d7B9cEA
        }),
        NFTData({
            namespace: "coNFT",
            name: "Community Ownership NFT",
            symbol: "coNFT",
            imageDescription: "Beincom - Community Ownership NFT@",
            imageUri: "https://media.beincom.app/image/uri/ocnft",
            nftAddress: 0xC3316F0C98939ba6dea7B8Dd204d7Ce632d546Ae
        }),
        NFTData({
            namespace: "poNFT",
            name: "Profile Ownership NFT",
            symbol: "poNFT",
            imageDescription: "Beincom - Profile Ownership NFT@",
            imageUri: "https://api.beincom.io/v1/wallet/uri/opnft",
            nftAddress: 0x2A63b11501f40c4af3d134eEa4bA6C18444ce562
        }),
        NFTData({
            namespace: "ubNFT",
            name: "Username Base NFT",
            symbol: "ubNFT",
            imageDescription: "Beincom - Username Base NFT@",
            imageUri: "https://media.beincom.app/image/uri/eunft",
            nftAddress: 0xB607ba4C0227d3eA7373207Cf689D12c17db0D51
        }),
        NFTData({
            namespace: "cbNFT",
            name: "Community Base NFT",
            symbol: "cbNFT",
            imageDescription: "Beincom - Community Base NFT@",
            imageUri: "https://media.beincom.app/image/uri/ecnft",
            nftAddress: 0xcC2f5d08Af7A54472dCDda8F575C5031Ac1056E1
        }),
        NFTData({
            namespace: "pbNFT",
            name: "Profile Base NFT",
            symbol: "pbNFT",
            imageDescription: "Beincom - Profile Base NFT@",
            imageUri: "https://media.beincom.app/image/uri/epnft",
            nftAddress: 0xe8D08f7410D71E752EC9986a3cdc50a3A5C7c1e9
        })
    ];


    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address controllerAddress = 0x5Be1D7b5552c39c0fd25C1C5cd9DfF0b094b9272;
        
        vm.startBroadcast(deployerPrivateKey);

        for (uint i = 0; i < nftDataList.length; i++) {
            NFTData memory nft = nftDataList[i];
            
            
            Handles clone = Handles(nft.nftAddress);
            clone.setController(controllerAddress);
        }

        vm.stopBroadcast();
    }
}
