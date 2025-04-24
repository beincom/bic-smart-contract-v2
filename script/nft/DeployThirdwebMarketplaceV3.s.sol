// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IPermissions} from "../../src/interfaces/IMarketplace.sol";



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



contract DeployThirdwebMarketplaceV3 is Script {
    bytes32 DEFAULT_ADMIN_ROLE = 0x00;

    // Same in multi chain
    address bicFactory = vm.envAddress("BIC_FACTORY_ADDRESS");
    address implementation = vm.envAddress("THIRD_WEB_MARKETPLACE_IMPLEMENTATION");
    address bicOwnerAddress = vm.envAddress("BIC_OWNER_ADDRESS");

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address forwarder = vm.envAddress("FORWARDER_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address[] memory trustedForwarders = new address[](1);
        trustedForwarders[0] = forwarder;
        vm.startBroadcast(deployerPrivateKey);
        SampleBicFactory factory = SampleBicFactory(bicFactory);
        address marketplaceAddress = factory.deployProxyByImplementation(
            implementation,
            abi.encodeWithSelector(
                SampleThirdwebMarketplaceV3.initialize.selector,
                vm.addr(deployerPrivateKey),
                "",
                trustedForwarders,
                treasury,
                600
            ),
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        console.log("ThirdwebMarketplaceV3 deployed at:", marketplaceAddress);    

        IPermissions marketplace = IPermissions(marketplaceAddress);
        marketplace.grantRole(DEFAULT_ADMIN_ROLE, bicOwnerAddress);
        
        vm.stopBroadcast();
    }

    function _postValidate(address marketplaceAddress) internal {
        IPermissions marketplace = IPermissions(marketplaceAddress);
        require(marketplace.hasRole(DEFAULT_ADMIN_ROLE, bicOwnerAddress), "BIC_OWNER_ADDRESS does not have DEFAULT_ADMIN_ROLE");
    }
}