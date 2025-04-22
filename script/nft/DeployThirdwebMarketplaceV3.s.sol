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

interface IRoyaltyPaymentsLogic  {
    function getRoyalty(
        address tokenAddress,
        uint256 tokenId,
        uint256 value
    ) external returns (address payable[] memory recipients, uint256[] memory amounts);

    function setRoyaltyEngine(address _royaltyEngineAddress) external;

    function getRoyaltyEngineAddress() external view returns (address royaltyEngineAddress);
    
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



contract DeployThirdwebMarketplaceV3 is Script {
    // Same in multi chain
    address bicFactory = vm.envAddress("BIC_FACTORY_ADDRESS");
    address implementation = vm.envAddress("THIRD_WEB_MARKETPLACE_IMPLEMENTATION");

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
            0x0000000000000000000000000000000000000000000000000000000000000003
        );
        console.log("ThirdwebMarketplaceV3 deployed at:", marketplace_address);
        IRoyaltyPaymentsLogic marketplace = IRoyaltyPaymentsLogic(marketplace_address);
        marketplace.setRoyaltyEngine(address(0));
        
        vm.stopBroadcast();
    }
}