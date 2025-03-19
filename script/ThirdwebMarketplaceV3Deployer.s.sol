// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract SampleBicFactory {
    function deployProxyByImplementation(
        address _implementation,
        bytes memory _data,
        bytes32 _salt
    ) public returns (address deployedProxy) {
        // Deploy the proxy
    }
}

contract SampleThirdwebMarketplaceV3 {
    function initialize(
        address _defaultAdmin,
        string memory _contractURI,
        address[] memory _trustedForwarders,
        address _platformFeeRecipient,
        uint16 _platformFeeBps
    ) external {
        // Initialize the contract
    }
}



contract ThirdwebMarketplaceV3Deployer is Script {
    // Same in multi chain
    address bicFactory = 0xfaCB1c58cFA14945f6F9Af3f4ad7Fd0A46490139;
    address implementation = 0xcD7d9B468c1c2cd21Ec7AE992e14868fB4802e24;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address forwarder = vm.envAddress("FORWARDER_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address[] memory trustedForwarders = new address[](1);
        trustedForwarders[0] = forwarder;
        vm.startBroadcast(deployerPrivateKey);
        SampleBicFactory factory = SampleBicFactory(bicFactory);
        address marketplace_address = factory.deployProxyByImplementation(
            implementation,
            abi.encodeWithSelector(
                SampleThirdwebMarketplaceV3.initialize.selector,
                vm.addr(deployerPrivateKey),
                "",
                trustedForwarders,
                treasury,
                600
            ),
            0x0000000000000000000000000000000000000000000000000000000000000001
        );
        console.log("ThirdwebMarketplaceV3 deployed at:", marketplace_address);
        vm.stopBroadcast();
    }
}