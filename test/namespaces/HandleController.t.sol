// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {HandlesController} from "../../src/namespaces/HandlesController.sol";
import {Handles} from "../../src/namespaces/Handles.sol";
import {IEnglishAuctions} from "../../src/interfaces/IMarketplace.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../../src/staking/TieredStakingPool.sol";
import "forge-std/Test.sol";

contract TestERC20 is ERC20 {
    constructor(address owner) ERC20("Test ERC20", "tERC20") {
        _mint(owner, 1e27);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MockEnglishAuction {
    uint256 public id;
    mapping(uint256 => IEnglishAuctions.Auction) public auctions;
    mapping(uint256 => IEnglishAuctions.Bid) public winningBids;
    IEnglishAuctions.Bid public testBid;
    uint256 public  feeBps = 600; // 6% fee.

    function setTestAuction(IEnglishAuctions.Auction memory auction, IEnglishAuctions.Bid memory bid) external {

     
    }

    function getAuction(uint256 _auctionId) external view returns (IEnglishAuctions.Auction memory auction) {
        auction = auctions[_auctionId];
    }

    function getWinningBid(uint256 _auctionId)
        external
        view
    
        returns (
            address bidder,
            address currency,
            uint256 bidAmount
        )
    {
        IEnglishAuctions.Auction memory auction = auctions[_auctionId];
        bidder = address(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697);
        currency = auction.currency;
        bidAmount = auction.buyoutBidAmount;
    }

    function collectAuctionPayout(uint256 _auctionId) external {
        // Do nothing.
        IEnglishAuctions.Auction memory auction = auctions[_auctionId];
        ERC20(auction.currency).transfer(auction.auctionCreator, (auction.buyoutBidAmount) * (10000 - feeBps) / 10000);
    }

    // Dummy implementations for createAuction and bidInAuction.
    function createAuction(IEnglishAuctions.AuctionParameters memory _params) external returns (uint256) {
        Handles(_params.assetContract).transferFrom(msg.sender, address(this), _params.tokenId);
        uint256 currentId = id;
        auctions[currentId] = IEnglishAuctions.Auction({
            auctionId: id,
            tokenId: _params.tokenId,
            quantity: 1,
            minimumBidAmount: _params.minimumBidAmount,
            buyoutBidAmount: _params.buyoutBidAmount,
            timeBufferInSeconds: _params.timeBufferInSeconds,
            bidBufferBps: _params.bidBufferBps,
            startTimestamp: _params.startTimestamp,
            endTimestamp: _params.endTimestamp,
            auctionCreator: msg.sender,
            assetContract: _params.assetContract,
            currency: _params.currency,
            tokenType: IEnglishAuctions.TokenType.ERC721,
            status: IEnglishAuctions.Status.CREATED
        });
        id++;
        return currentId;
    }

    function bidInAuction(uint256 _auctionId, uint256 _bidAmount) external {
        IEnglishAuctions.Auction storage auction = auctions[_auctionId];
        auction.endTimestamp = uint64(block.timestamp);
        
       
    }
    
}


contract HandleControllerTest is Test {
    MockEnglishAuction marketplace;
    Handles handle;
    HandlesController handlesController;
    TestERC20 bic;

    uint256 owner_private_key = 0xb1c;
    address owner = vm.addr(owner_private_key);

    uint256 verifier_private_key = 0xb2c;
    address verifier = vm.addr(verifier_private_key);

    uint256 collector_private_key = 0xb3c;
    address collector = vm.addr(collector_private_key);

    
    function setUp() public {
        vm.startPrank(owner);
        marketplace = new MockEnglishAuction();
        handle = new Handles();
        handle.initialize(
            "namespace",
            "Handle",
            "HNDL",
            owner
        );

        bic = new TestERC20(owner);
        handlesController = new HandlesController(bic, owner);

        handle.setController(address(handlesController));
        
        handlesController.setVerifier(verifier);
        handlesController.setMarketplace(address(marketplace));
        handlesController.setCollector(collector);

        // Transfer BIC to marketplace instead of bid auction
        bic.mint(address(marketplace), 1e27);

        // register the handle
        _createNFTAuction();
       
        vm.stopPrank();
    }

    function _createNFTAuction() private {
        HandlesController.HandleRequest memory rq = HandlesController.HandleRequest({
            receiver: address(this), // Address to receive the handle.
            handle: address(handle), // Contract address of the handle.
            name: "testHandle", // Name of the handle.
            price: 1 ether, // Price to be paid for the handle.
            beneficiaries: new address[](0), // Beneficiaries for the handle's payment.
            collects: new uint256[](0), // Shares of the proceeds for each beneficiary.
            commitDuration: 5 * 3600, // Duration for which the handle creation can be committed (reserved).
            buyoutBidAmount: 200 ether, // Buyout bid amount for the auction.
            timeBufferInSeconds: 10, // Time buffer for the auction.
            bidBufferBps: 1000, // Bid buffer for the auction.
            isAuction: true // Indicates if the handle request is for an auction.
        });
        uint256 validUntil = block.timestamp + 3600;
        uint256 validAfter = block.timestamp;
        vm.warp(block.timestamp + 1); // Increase time by 1 seconds to simulate auction duration.

        bytes32 dataHash = handlesController.getRequestHandleOp(rq, validUntil, validAfter);
        bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(dataHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(verifier_private_key, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        handlesController.requestHandle(rq, validUntil, validAfter, signature);
        // Set the auction status to CREATED.
    }

    function test_claim_auction() public {
        uint256 auctionId = 0;
        IEnglishAuctions.Auction memory auction = marketplace.getAuction(auctionId);


        vm.warp(auction.endTimestamp + 3600); // Increase time by 1 seconds to simulate auction duration.

        marketplace.bidInAuction(auctionId, auction.buyoutBidAmount);
        marketplace.collectAuctionPayout(auctionId);

        // Fee 600 = 6%
        uint256 payoutAmount = (auction.buyoutBidAmount) * (10000 - 600) / 10000;
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = address(0x1111);
        uint256[] memory collects = new uint256[](1);
        // Use the full denominator.
        collects[0] = 1000; 

        // Build the hash to be signed as in getCollectAuctionPayoutOp.
        bytes32 dataHash = handlesController.getCollectAuctionPayoutOp(auctionId, payoutAmount, beneficiaries, collects);
        bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(dataHash);

          // Sign the dataHash using the dummy verifier private key.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(verifier_private_key, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);

         // Record the initial token balance of the beneficiary.
        uint256 beneficiaryBalanceBefore = bic.balanceOf(beneficiaries[0]);
        uint256 treasuryBalanceBefore = bic.balanceOf(collector);

        // Call collectAuctionPayout.
        handlesController.collectAuctionPayout(auctionId, payoutAmount, beneficiaries, collects, signature);

        // Verify that the auction can no longer be claimed.
        bool canClaim = handlesController.auctionCanClaim(auctionId);
        assertFalse(canClaim, "Auction claim flag should be false after successful payout");

        // Verify that the beneficiary received the correct amount.
        uint256 beneficiaryBalanceAfter = bic.balanceOf(beneficiaries[0]);
        uint256 treasuryBalanceAfter = bic.balanceOf(collector);
        
        assertEq(
            beneficiaryBalanceAfter - beneficiaryBalanceBefore,
            (payoutAmount * collects[0]) / 10000,
            "Beneficiary did not receive the correct payout amount"
        );
        assertEq(
            treasuryBalanceAfter - treasuryBalanceBefore,
            (payoutAmount * (10000 - collects[0])) / 10000,
            "Treasury did not receive the correct payout amount"
        );
    }

}