// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HandlesController} from "../../src/namespaces/HandlesController.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IMulticall3 {
  struct Call {
    address target;
    bytes callData;
  }

  struct Call3 {
    address target;
    bool allowFailure;
    bytes callData;
  }

  struct Call3Value {
    address target;
    bool allowFailure;
    uint256 value;
    bytes callData;
  }

  struct Result {
    bool success;
    bytes returnData;
  }

  function aggregate(Call[] calldata calls)
    external
    payable
    returns (uint256 blockNumber, bytes[] memory returnData);

  function aggregate3(Call3[] calldata calls) external payable returns (Result[] memory returnData);

  function aggregate3Value(Call3Value[] calldata calls)
    external
    payable
    returns (Result[] memory returnData);
}
contract PremintNFTScript is Script {
    using ECDSA for bytes32;

    // Contract addresses and key configs
    address public handlesController;
    address public uoNFTHandle;
    address public poNFTHandle;
    address public coNFTHandle;
    address public receiver;
    address public multicall;
    uint256 public signerPrivateKey;

    // Struct to hold handle request data
    struct HandleRequestData {
        string name;
        address handleContract;
    }

    function setUp() public {
        // Update addresses
        handlesController = 0xc26c0b7DF79aAf4F6a8fc9458BD1F8BE2447b8Fd;
        uoNFTHandle = 0x28F5452907408199c3b8683D2752414B5d7B9cEA;
        poNFTHandle = 0x2A63b11501f40c4af3d134eEa4bA6C18444ce562;
        coNFTHandle = 0xC3316F0C98939ba6dea7B8Dd204d7Ce632d546Ae;
        receiver = 0xe450584F78be9DdeA56A535125Aa400F67BAbA36;
        multicall = 0xcA11bde05977b3631167028862bE2a173976CA11;
        signerPrivateKey = vm.envUint("NFT_VERIFIER_PRIVATE_KEY");
    }

    function run() public {

        HandleRequestData[] memory allHandles = getAllHandleRequests();
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](allHandles.length);
        
        // Empty arrays for beneficiaries and collects
        address[] memory beneficiaries = new address[](0);
        uint256[] memory collects = new uint256[](0);
        
        // Calculate validity period (same for all requests)
        uint256 validAfter = block.timestamp - 1;
        uint256 validUntil = block.timestamp + 1 hours;

        // Prepare all calls
        for (uint i = 0; i < allHandles.length; i++) {
            HandlesController.HandleRequest memory request = HandlesController.HandleRequest({
                receiver: receiver,
                handle: allHandles[i].handleContract,
                name: allHandles[i].name,
                price: 0,
                beneficiaries: beneficiaries,
                collects: collects,
                commitDuration: 0,
                buyoutBidAmount: 0,
                timeBufferInSeconds: 0,
                bidBufferBps: 0,
                isAuction: false
            });

            // Get message hash and signature
            bytes32 messageHash = HandlesController(handlesController).getRequestHandleOp(
                request,
                validUntil,
                validAfter
            );
            bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMessageHash);
            bytes memory signature = abi.encodePacked(r, s, v);

            // Prepare multicall data
            calls[i] = IMulticall3.Call3({
                target: handlesController,
                allowFailure: false,
                callData: abi.encodeWithSelector(
                    HandlesController.requestHandle.selector,
                    request,
                    validUntil,
                    validAfter,
                    signature
                )
            });

            console.log("Prepared request for handle:", allHandles[i].name);
            console.log("Handle contract:", allHandles[i].handleContract);
        }

        // Execute all calls in a single transaction
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        IMulticall3(multicall).aggregate3(calls);
        vm.stopBroadcast();
    }

    function getAllHandleRequests() internal view returns (HandleRequestData[] memory) {
        // Username Ownership NFTs (uoNFT)
        HandleRequestData[] memory uoHandles = new HandleRequestData[](9);
        uoHandles[0] = HandleRequestData("contact", uoNFTHandle);
        uoHandles[1] = HandleRequestData("bicsupport", uoNFTHandle);
        uoHandles[2] = HandleRequestData("beincom.global.admin", uoNFTHandle);
        uoHandles[3] = HandleRequestData("crisbicsupport", uoNFTHandle);
        uoHandles[4] = HandleRequestData("lilybicsupport", uoNFTHandle);
        uoHandles[5] = HandleRequestData("canarybicsupport", uoNFTHandle);
        uoHandles[6] = HandleRequestData("dylanbicsupport", uoNFTHandle);
        uoHandles[7] = HandleRequestData("beincom", uoNFTHandle);
        uoHandles[8] = HandleRequestData("beincomadmin", uoNFTHandle);

        // Personal Name Ownership NFTs (poNFT)
        HandleRequestData[] memory poHandles = new HandleRequestData[](9);
        poHandles[0] = HandleRequestData("Beincom Official", poNFTHandle);
        poHandles[1] = HandleRequestData("Beincom Vietnam Admin", poNFTHandle);
        poHandles[2] = HandleRequestData("Beincom Global Admin", poNFTHandle);
        poHandles[3] = HandleRequestData("Lily Beincom Support", poNFTHandle);
        poHandles[4] = HandleRequestData("Canary Beincom Support", poNFTHandle);
        poHandles[5] = HandleRequestData("Cris Beincom Support", poNFTHandle);
        poHandles[6] = HandleRequestData("Dylan Beincom Support", poNFTHandle);
        poHandles[7] = HandleRequestData("Beincom", poNFTHandle);
        poHandles[8] = HandleRequestData("Beincom Admin", poNFTHandle);

        // Community Name Ownership NFTs (coNFT)
        HandleRequestData[] memory coHandles = new HandleRequestData[](5);
        coHandles[0] = HandleRequestData("Beincom Viet Nam", coNFTHandle);
        coHandles[1] = HandleRequestData("Beincom Global", coNFTHandle);
        coHandles[2] = HandleRequestData("Beincom's EchoSphere", coNFTHandle);
        coHandles[3] = HandleRequestData("Beincom", coNFTHandle);
        coHandles[4] = HandleRequestData("Beincom Admin", coNFTHandle);

        // Combine all handles
        HandleRequestData[] memory allHandles = new HandleRequestData[](
            uoHandles.length + poHandles.length + coHandles.length
        );
        
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < uoHandles.length; i++) {
            allHandles[currentIndex++] = uoHandles[i];
        }
        for (uint256 i = 0; i < poHandles.length; i++) {
            allHandles[currentIndex++] = poHandles[i];
        }
        for (uint256 i = 0; i < coHandles.length; i++) {
            allHandles[currentIndex++] = coHandles[i];
        }

        return allHandles;
    }
}
