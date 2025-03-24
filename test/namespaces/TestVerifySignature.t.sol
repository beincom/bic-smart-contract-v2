pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";


import {MockMarketplace} from "./mocks/MockMarketplace.t.sol";
import {TestBIC} from "./mocks/TestBIC.t.sol";
import {HandlesController} from "../../src/namespaces/HandlesController.sol";
import {Handles} from "../../src/namespaces/Handles.sol";


contract HandlesControllerImpl is HandlesController {
    // This setter is for testing to simulate the auctionCanClaim mapping.
    constructor(ERC20 bic, address owner) HandlesController(bic, owner) {}
}

// ------------------ TEST CONTRACT ------------------
contract HandlesControllerTest is Test {
    uint256 owner_private_key = 0xb1c;
    address owner = vm.addr(owner_private_key);

    uint256 controller_private_key = 0xc1c;
    address controllerAddress = vm.addr(controller_private_key);

    TestBIC bic;
    Handles mockHandles;
    MockMarketplace mockMarketplace;
    HandlesControllerImpl controller;
    function setUp() public {
        vm.startPrank(owner);
        // Deploy the test token.
        bic = new TestBIC();

        // Deploy mocks.

        mockMarketplace = new MockMarketplace();

        // Deploy HandlesController implementation.
        controller = new HandlesControllerImpl(bic, owner);
        controller.setMarketplace(address(mockMarketplace));
        controller.setCollector(address(bic));
        controller.setController(controllerAddress);


        mockHandles = new Handles();
        mockHandles.initialize("upNFT", "UO", "NFT", owner);
        mockHandles.setController(address(controller));
    }

    function testRequestHandleSignatureVerification() public {
        // Prepare HandlesControllerImpl.HandleRequest data.
        vm.startPrank(owner);
        bic.mint(owner, 1000 ether);
        bic.approve(address(controller), 1000 ether);
        HandlesController.HandleRequest memory rq = HandlesController.HandleRequest({
            receiver: address(0x5678),
            handle: address(mockHandles),
            name: "testHandleName",
            price: 1 ether,
            beneficiaries: new address[](2),
            collects: new uint256[](2),
            commitDuration: 0,
            buyoutBidAmount: 200 ether,
            timeBufferInSeconds: 300,
            bidBufferBps: 500,
            isAuction: false
        });
        rq.beneficiaries[0] = address(0x1111);
        rq.beneficiaries[1] = address(0x2222);
        rq.collects[0] = 50;
        rq.collects[1] = 50;

        // skip for prevent underflow: validAfter
        vm.warp(block.timestamp + 3600);

        uint256 validUntil = block.timestamp + 3600;
        uint256 validAfter = block.timestamp - 1;

        // Hash the request data.
        bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(controller.getRequestHandleOp(rq, validUntil, validAfter));

        // Sign the msgHash with the controller's private key.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(controller_private_key, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Prank as the requester and call requestHandle.
        controller.requestHandle(rq, validUntil, validAfter, signature);

        // Verify that the handle was successfully requested.
        // This assumes the `Handles` contract has a method to check ownership of a handle.
        assertEq(mockHandles.ownerOf(mockHandles.getTokenId(rq.name)), rq.receiver, "Handle ownership mismatch");
    }

    function testRequestHandleInvalidSignature() public {
        // Prepare HandleRequest data.
        vm.startPrank(owner);
        bic.mint(owner, 1000 ether);
        bic.approve(address(controller), 1000 ether);
        
        HandlesController.HandleRequest memory rq = HandlesController.HandleRequest({
            receiver: address(0x5678),
            handle: address(mockHandles),
            name: "testHandleName_failed",
            price: 1 ether,
            beneficiaries: new address[](2),
            collects: new uint256[](2),
            commitDuration: 0,
            buyoutBidAmount: 200 ether,
            timeBufferInSeconds: 300,
            bidBufferBps: 500,
            isAuction: false
        });

        rq.beneficiaries[0] = address(0x1111);
        rq.beneficiaries[1] = address(0x2222);
        rq.collects[0] = 50;
        rq.collects[1] = 50;

         // skip for prevent underflow: validAfter
        vm.warp(block.timestamp + 3600);

        uint256 validUntil = block.timestamp + 3600;
        uint256 validAfter = block.timestamp - 1;

        // Hash the request data.
        bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(controller.getRequestHandleOp(rq, validUntil, validAfter));

        // Sign the hash with an invalid private key (not the controller's).
        uint256 invalidPrivateKey = 0xd1c;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(invalidPrivateKey, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Prank as the requester and attempt to call requestHandle.
        vm.expectRevert(HandlesController.InvalidRequestSignature.selector);
        controller.requestHandle(rq, validUntil, validAfter, signature);
        vm.stopPrank();
    }
}
