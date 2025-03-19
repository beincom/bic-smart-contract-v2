// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Handles} from "../src/namespaces/Handles.sol";
import {HandleTokenURI} from "../src/namespaces/HandleTokenURI.sol";
import {HandlesController} from "../src/namespaces/HandlesController.sol";
import {BicForwarder} from "../src/forwarder/BicForwarder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract HandleBaseDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployOwner = vm.addr(deployerPrivateKey);
        address afterDeployOwner = vm.envAddress("AFTER_DEPLOY_OWNER");
        vm.startBroadcast(deployerPrivateKey);
        deployHandleUri(deployOwner, afterDeployOwner);
        deployHandle();
        deployHandleController(deployOwner, afterDeployOwner);
        vm.stopBroadcast();
    }

    function deployHandleUri(address deployOwner, address afterDeployOwner) internal {
        HandleTokenURI handleTokenURI = new HandleTokenURI(deployOwner);
        console.log("HandleTokenURI deployed at:", address(handleTokenURI));
        // handleTokenURI.transferOwnership(afterDeployOwner);
    }

    function deployHandle() internal {
        Handles handle = new Handles();
        console.log("Handles deployed at:", address(handle));
    }

    function deployHandleController(address deployOwner, address afterDeployOwner) internal {
        address forwarder = vm.envAddress("FORWARDER_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address marketPlace = vm.envAddress("MARKETPLACE_ADDRESS");
        address verifier = vm.envAddress("HANDLE_CONTROLLER_VERIFIER_ADDRESS");
        address bic = vm.envAddress("BIC_ADDRESS");
        HandlesController handleController = new HandlesController(IERC20(bic), deployOwner);
        handleController.setForwarder(forwarder);
        handleController.setCollector(treasury);
        handleController.setMarketplace(marketPlace);
        handleController.setVerifier(verifier);
        console.log("HandleController deployed at:", address(handleController));
        // handleController.transferOwnership(afterDeployOwner);

        BicForwarder bicForwarder = BicForwarder(forwarder);
        bicForwarder.addController(address(handleController));
    }
}

