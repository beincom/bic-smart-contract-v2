// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HandlesController} from "../../src/namespaces/HandlesController.sol";
import {Handles} from "../../src/namespaces/Handles.sol";
import {IEnglishAuctions, IPlatformFee} from "../../src/interfaces/IMarketplace.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
contract SimulateThirdwebMarketplaceAuction is Script {
    using ECDSA for bytes32;

    // Contract addresses and key configs
    address public thirdwebAddress = 0x1Af20C6B23373350aD464700B5965CE4B0D2aD94;
    address public bicAddress;
    address public treasuryAddress;
    address public handlesController;
    address public marketplaceAddress;
    address public poNFTHandle;
    address public receiver;
    address public multicall;
    uint256 public operatorPrivateKey;

    // Struct to hold handle request data
    struct HandleRequestData {
        string name;
        address handleContract;
    }

    function setUp() public {
        // Update addresses
        bicAddress = vm.envAddress("BIC_ADDRESS");
        treasuryAddress = vm.envAddress("TREASURY_ADDRESS");
        handlesController = vm.envAddress("CONTROLLER_ADDRESS");
        marketplaceAddress = vm.envAddress("MARKETPLACE_ADDRESS");
        poNFTHandle = vm.envAddress("NFT_OWNERSHIP_PERSONAL_NAME_COLLECTION_ADDRESS");
        receiver = vm.envAddress("PREMINT_RECEIVER_ADDRESS");
        multicall = 0xcA11bde05977b3631167028862bE2a173976CA11;
        operatorPrivateKey = vm.envUint("NFT_OPERATOR_PRIVATE_KEY");
    }

    function run() public {
        mintNFTForTest();
        test1PercentAndRoyalty();
    }

    function test1PercentAndRoyalty() public {
        vm.startBroadcast(receiver);

        IEnglishAuctions marketplace = IEnglishAuctions(marketplaceAddress);
        IERC20 bic = IERC20(bicAddress);
        Handles handle = Handles(poNFTHandle);

        uint256 tokenId = handle.getTokenId(unicode"Test tên cá nhân");
        handle.approve(marketplaceAddress, tokenId);
        
        IEnglishAuctions.AuctionParameters memory auctionParam = IEnglishAuctions.AuctionParameters({
            assetContract: poNFTHandle,
            tokenId: tokenId, // replace with actual token ID
            quantity: 1, // usually 1 for ERC721, can be more for ERC1155
            currency: bicAddress, // address(0) for native currency (ETH), or ERC20 address
            minimumBidAmount: 1e16, // set your minimum bid (in wei)
            buyoutBidAmount: 1e17, // set your buyout bid (in wei)
            timeBufferInSeconds: 900, // 15 minutes
            bidBufferBps: 500, // 5% buffer = 500 bps
            startTimestamp: uint64(block.timestamp), // starts in 1 hour
            endTimestamp: uint64(block.timestamp + 86400) // ends in 24 hours
        });
        uint256 auctionId = marketplace.createAuction(auctionParam);
        vm.stopBroadcast();

    
        uint256 preBalanceOfThirdweb = bic.balanceOf(thirdwebAddress);
        uint256 preBalanceOfReceiver = bic.balanceOf(receiver); 
        uint256 preBalanceOfTreasury = bic.balanceOf(treasuryAddress);

        address bidder = vm.envAddress("BIC_OWNER_ADDRESS");
        vm.startBroadcast(bidder);
        bic.approve(marketplaceAddress, 200 ether);
        marketplace.bidInAuction(auctionId, auctionParam.buyoutBidAmount);
        marketplace.collectAuctionPayout(auctionId);
        vm.stopBroadcast();

        // Validate collect bid and nft
        address currentOwnerOfHandle = handle.ownerOf(tokenId);
        require(currentOwnerOfHandle == bidder, "Current owner nft does not match");
        

        (,uint16 feeBps) = IPlatformFee(marketplaceAddress).getPlatformFeeInfo();

        uint256 postBalanceOfReceiver = bic.balanceOf(receiver);
        uint256 postBalanceOfTreasury = bic.balanceOf(treasuryAddress);
        uint256 postBalanceOfThirdweb = bic.balanceOf(thirdwebAddress);

        require(postBalanceOfThirdweb == preBalanceOfThirdweb, "Thirdweb balance should match");

        uint256 expectedBalanceOfTreasury = preBalanceOfTreasury + (auctionParam.buyoutBidAmount * feeBps) / 10000;
        require(postBalanceOfTreasury == expectedBalanceOfTreasury, "Treasury balance does not match");
        
        uint256 expectedBalance = preBalanceOfReceiver + (auctionParam.buyoutBidAmount * (10000 - feeBps)) / 10000;
        require(postBalanceOfReceiver == expectedBalance, "Receiver balance does not match");

        
    }

    function mintNFTForTest() public {

        HandleRequestData[] memory allHandles = getAllHandleRequestsForTest();
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
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(operatorPrivateKey, ethSignedMessageHash);
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


        // Verify all handles are owned by receiver
        for (uint256 i = 0; i < allHandles.length; i++) {
            Handles handle = Handles(allHandles[i].handleContract);
            require(
                handle.ownerOf(handle.getTokenId(allHandles[i].name)) == receiver,
                "Handle NFT not owned by receiver"
            );
        }
        
        vm.stopBroadcast();
    }

    function getAllHandleRequestsForTest() internal view returns (HandleRequestData[] memory) {

        // Personal Name Ownership NFTs (poNFT)
        HandleRequestData[] memory poHandles = new HandleRequestData[](1);
        poHandles[0] = HandleRequestData(unicode"Test tên cá nhân", poNFTHandle);

        // Combine all handles
        HandleRequestData[] memory allHandles = new HandleRequestData[](
            poHandles.length
        );
        
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < poHandles.length; i++) {
            allHandles[currentIndex++] = poHandles[i];
        }

        return allHandles;
    }
}
