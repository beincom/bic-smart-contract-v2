pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {MockMarketplace} from "./mocks/MockMarketplace.t.sol";
import {TestBIC} from "./mocks/TestBIC.t.sol";
import {HandlesController} from "../../src/namespaces/HandlesController.sol";
import {Handles} from "../../src/namespaces/Handles.sol";


contract HandlesControllerImpl is HandlesController {
    // This setter is for testing to simulate the auctionCanClaim mapping.
    constructor(ERC20 bic, address owner) HandlesController(bic, owner) {}
    function setAuctionCanClaim(uint256 auctionId, bool canClaim) external onlyOwner {
        auctionCanClaim[auctionId] = canClaim;
    }
}

// ------------------ TEST CONTRACT ------------------
contract HandlesControllerTest is Test {
    uint256 owner_private_key = 0xb1c;
    address owner = vm.addr(owner_private_key);

    TestBIC bic;
    Handles mockHandles;
    MockMarketplace mockMarketplace;
    HandlesControllerImpl controller;
    address beneficiary1 = address(0x1111);
    address beneficiary2 = address(0x2222);
    address collector = address(0x3333);
    address auctionWinner = address(0x4444);
    uint256 auctionId = 1;
    uint256 bidAmount = 1000 * 1e18;

    function setUp() public {
        vm.startPrank(owner);
        // Deploy the test token.
        bic = new TestBIC();

        // Deploy mocks.

        mockMarketplace = new MockMarketplace();

        // Deploy HandlesController implementation.
        controller = new HandlesControllerImpl(bic, owner);
        controller.setMarketplace(address(mockMarketplace));
        controller.setCollector(collector);


        mockHandles = new Handles();
        mockHandles.initialize("upNFT", "UO", "NFT", owner);
        mockHandles.setController(address(controller));



        vm.warp(block.timestamp + 3600);

        uint64 auctionEnd = uint64(block.timestamp - 10);
        mockMarketplace.setAuction(auctionId, address(mockHandles), address(bic), address(controller), 1, auctionEnd);
        // Set winning bid: auction winner with bid amount 1000.
        bic.mint(address(mockMarketplace), bidAmount);
        mockMarketplace.setWinningBid(auctionId, auctionWinner, bidAmount);

        // Mark auction as claimable.
        controller.setAuctionCanClaim(auctionId, true);
    }


    function testCollectAndShareRevenueSuccessful() public {
        // Collect and share revenue for a single auction.

        // Record balances before payout.
        uint256 balBeforeBen1 = bic.balanceOf(beneficiary1);
        uint256 balBeforeBen2 = bic.balanceOf(beneficiary2);
        uint256 balBeforeCollector = bic.balanceOf(collector);

       
       
        uint256[] memory collects = new uint256[](2);
        collects[0] = 5000; // 50%
        collects[1] = 4000; // 40%
        
        uint256[] memory auctionIds = new uint256[](1);
        auctionIds[0] = auctionId;


        uint256 distributionAmount = bidAmount * (10000 - 600) / 10000;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = distributionAmount;

        address[][] memory beneficiariesList = new address[][](1);
        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = beneficiary1;
        beneficiaries[1] = beneficiary2;
        beneficiariesList[0] = beneficiaries;

        uint256[][] memory collectsList = new uint256[][](1);
        collectsList[0] = collects;

        bool[] memory isAuctionsCollectedList = new bool[](1);
        isAuctionsCollectedList[0] = true;

        controller.collectAndShareRevenue(auctionIds, amounts, beneficiariesList, collectsList, isAuctionsCollectedList);

        // Verify auctionCanClaim has been updated.
        assertFalse(controller.auctionCanClaim(auctionId), "Auction should not be claimable after revenue collection");

        // Calculate and verify correct payouts.
        uint256 balAfterBen1 = bic.balanceOf(beneficiary1);
        uint256 balAfterBen2 = bic.balanceOf(beneficiary2);
        uint256 balAfterCollector = bic.balanceOf(collector);

        assertEq(balAfterBen1 - balBeforeBen1, (distributionAmount * collects[0]) / 10000, "Beneficiary1 did not receive the correct amount");
        assertEq(balAfterBen2 - balBeforeBen2, (distributionAmount * collects[1]) / 10000, "Beneficiary2 did not receive the correct amount");

        // No residual funds should remain for the collector in this distribution.
        assertEq(balAfterCollector - balBeforeCollector, distributionAmount * (10000 - collects[0] - collects[1]) / 10000, "Collector should receive remaining funds");
    }
}
