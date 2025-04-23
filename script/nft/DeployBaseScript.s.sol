// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handles} from "../../src/namespaces/Handles.sol";
import {HandleTokenURI} from "../../src/namespaces/HandleTokenURI.sol";
import {HandlesController} from "../../src/namespaces/HandlesController.sol";
import {BicForwarder} from "../../src/forwarder/BicForwarder.sol";

contract DeployBaseScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployOwner = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        deployHandle();
        deployHandleController(deployOwner);
        deployBICForwarder(deployOwner);
        deployHandleTokenURI(deployOwner);
        vm.stopBroadcast();
    }

    function deployHandle() internal {
        Handles handle = new Handles();
        console.log("Handles deployed at:", address(handle));
    }

    function deployHandleTokenURI(address deployOwner) internal {
        HandleTokenURI handleTokenURI = new HandleTokenURI(deployOwner);
        console.log("HandleTokenURI deployed at:", address(handleTokenURI));
    }

    function deployBICForwarder(address deployOwner) internal {
        BicForwarder bicForwarder = new BicForwarder(deployOwner);
        console.log("BicForwarder deployed at:", address(bicForwarder));
    }

    function deployHandleController(address deployOwner) internal {
        address bic = vm.envAddress("BIC_ADDRESS");
        HandlesController handleController = new HandlesController(IERC20(bic), deployOwner);
       
        console.log("HandleController deployed at:", address(handleController));
    }
}

