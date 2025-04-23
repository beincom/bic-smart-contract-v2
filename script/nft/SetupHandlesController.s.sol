// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handles} from "../../src/namespaces/Handles.sol";
import {HandleTokenURI} from "../../src/namespaces/HandleTokenURI.sol";
import {HandlesController} from "../../src/namespaces/HandlesController.sol";
import {BicForwarder} from "../../src/forwarder/BicForwarder.sol";

contract SetupHandlesControllerAndForwarderScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployOwner = vm.addr(deployerPrivateKey);
        address marketplaceAddress = vm.envAddress("MARKETPLACE_ADDRESS"); 
        address controllerAddress = vm.envAddress("CONTROLLER_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address forwarder = vm.envAddress("FORWARDER_ADDRESS");
        address operator = vm.envAddress("HANDLE_CONTROLLER_OPERATOR_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        HandlesController handlesController = HandlesController(controllerAddress);
        handlesController.setMarketplace(marketplaceAddress);
        handlesController.setForwarder(forwarder);
        handlesController.setCollector(treasury);

        handlesController.setOperator(deployOwner); // for PreMint NFT, it will remove in PostSetup.s.sol
        handlesController.setOperator(operator);


        BicForwarder bicForwarder = BicForwarder(forwarder);
        bicForwarder.addController(address(handlesController));
        
        vm.stopBroadcast();
    }
}

