// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {HandlesController} from "../src/namespaces/HandlesController.sol";
import {Handles} from "../src/namespaces/Handles.sol";

contract DeployHandleControllerScript is Script {
    address bic = 0xFc53d455c2694E3f25A02bF5a8F7a88520b77F07;
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        HandlesController handleController = new HandlesController(IERC20(bic), vm.addr(deployerPrivateKey));
        console.log("HandlesController deployed at:", address(handleController));
        vm.stopBroadcast();
    }
}

contract ConfigureHandleControllerScript is Script {
    HandlesController handleController = HandlesController(0x5Be1D7b5552c39c0fd25C1C5cd9DfF0b094b9272);
    address forwarder = 0x73cc7bD89065028C700aA6b3102089938dCAbcd5;
    address bic = 0xFc53d455c2694E3f25A02bF5a8F7a88520b77F07;
    address marketplace = 0x134231A5F66637625c90D65a3bc5Be187BB94466;
    address collector = 0xC9167C15f539891B625671b030a0Db7b8c08173f;
    address verifier = 0x42F1202e97EF9e9bEeE57CF9542784630E5127A7;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        handleController.setForwarder(forwarder);
        handleController.setCollector(collector);
        handleController.setVerifier(verifier);
        handleController.setMarketplace(marketplace);
        console.log("HandlesController configured successfully");

        vm.stopBroadcast();
    }
}

contract TestCreateNftScript is Script {
    
    HandlesController handleController = HandlesController(0x5Be1D7b5552c39c0fd25C1C5cd9DfF0b094b9272);
    Handles nft = Handles(0xe8D08f7410D71E752EC9986a3cdc50a3A5C7c1e9);
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 verifierPrivateKey = vm.envUint("NFT_VERIFIER_PRIVATE_KEY");
        uint256 validUntil = block.timestamp + 3 days;
        uint256 validAfter = block.timestamp - 1;
        vm.startBroadcast(deployerPrivateKey);
        IERC20 bic = handleController.bic();
        address marketplace = handleController.marketplace();
        // bic.approve(address(handleController), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        // bic.approve(marketplace, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

        HandlesController.HandleRequest memory rq = HandlesController.HandleRequest({
            receiver: address(0x5dB1194e856E75542e3Da9b7ff98Aa51123d00f0), // Replace with the receiver's address
            handle: address(nft),
            name: "exampleHandle_7",
            price: 1 ether,
            beneficiaries: new address[](0),
            collects: new uint256[](0),
            commitDuration: 600,
            buyoutBidAmount: 10 ether,
            timeBufferInSeconds: 300,
            bidBufferBps: 500,
            isAuction: true
        });

        bytes32 dataHash = handleController.getRequestHandleOp(rq, validUntil, validAfter);
        bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(dataHash);

          // Sign the dataHash using the dummy verifier private key.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(verifierPrivateKey, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        handleController.requestHandle(rq, validUntil, validAfter, signature);

        console.log("HandlesController configured successfully");

        vm.stopBroadcast();
    }
}