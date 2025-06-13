// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handles} from "../../src/namespaces/Handles.sol";
import {DupHandlesController} from "../../src/namespaces/DupHandlesController.sol";
import {BicForwarder} from "../../src/forwarder/BicForwarder.sol";

contract DeployAndSetupDupHandlesController is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address marketplaceAddress = vm.envAddress("MARKETPLACE_ADDRESS"); 
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address forwarder = vm.envAddress("FORWARDER_ADDRESS");
        address operator = vm.envAddress("HANDLE_CONTROLLER_OPERATOR_ADDRESS");
        address bic = vm.envAddress("BIC_ADDRESS");
        address dupHandlesControllerOwner = vm.envAddress("DUPHANDLE_CONTROLLER_OWNER"); 

        vm.startBroadcast(deployerPrivateKey);

        DupHandlesController dupHandlesController = new DupHandlesController(IERC20(bic), dupHandlesControllerOwner);
       
        console.log("HandleController deployed at:", address(dupHandlesController));

        dupHandlesController.setMarketplace(marketplaceAddress);
        dupHandlesController.setForwarder(forwarder);
        dupHandlesController.setCollector(treasury);

        dupHandlesController.setOperator(operator);

        BicForwarder bicForwarder = BicForwarder(forwarder);
        bicForwarder.addController(address(dupHandlesController));
        
        vm.stopBroadcast();
    }
}

