// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HandlesController} from "../src/namespaces/HandlesController.sol";

contract DeployHandleControllerScript is Script {
    address forwarder = 0xc4C47b7539F7876485b96DE6970c602050810Ca5;
    address bic = 0xFc53d455c2694E3f25A02bF5a8F7a88520b77F07;
    address marketplace = 0x134231A5F66637625c90D65a3bc5Be187BB94466;
    address collector = 0x134231A5F66637625c90D65a3bc5Be187BB94466;
    address verifier = vm.addr(vm.envUint("NFT_VERIFIER_PRIVATE_KEY"));

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        HandlesController handleController = new HandlesController(IERC20(bic), vm.addr(deployerPrivateKey));
        handleController.setForwarder(forwarder);
        handleController.setCollector(collector);
        handleController.setVerifier(verifier);
        handleController.setMarketplace(marketplace);
        console.log("HandlesController deployed at:", address(handleController));
        vm.stopBroadcast();
    }
}
