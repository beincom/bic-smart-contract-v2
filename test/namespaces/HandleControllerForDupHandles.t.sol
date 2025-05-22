pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {MockMarketplace} from "./mocks/MockMarketplace.t.sol";
import {TestBIC} from "./mocks/TestBIC.t.sol";
import {HandlesController} from "../../src/namespaces/HandlesController.sol";
import {DupHandles} from "../../src/namespaces/DupHandles.sol";


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

    uint256 controller_private_key = 0xc1c;
    address controllerAddress = vm.addr(controller_private_key);

    TestBIC bic;
    DupHandles mockHandles;
    MockMarketplace mockMarketplace;
    HandlesControllerImpl controller;
    address beneficiary1 = address(0x1111);
    address beneficiary2 = address(0x2222);
    address collector = address(0x3333);
    
    address auctionWinner = address(0x4444);
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
        controller.setOperator(controllerAddress);


        mockHandles = new DupHandles();
        mockHandles.initialize("upNFT", "UO", "NFT", owner);
        mockHandles.setOperator(address(controller));

        
    }

    function setUpMarketplace(uint256 auctionId) internal {
        vm.warp(block.timestamp + 3600);
        uint64 auctionEnd = uint64(block.timestamp - 10);
        mockMarketplace.setAuction(auctionId, address(mockHandles), address(bic), address(controller), 1, auctionEnd);
        // Set winning bid: auction winner with bid amount 1000.
        bic.mint(address(mockMarketplace), bidAmount);
        mockMarketplace.setWinningBid(auctionId, auctionWinner, bidAmount);

        // Mark auction as claimable.
        controller.setAuctionCanClaim(auctionId, true);
    }

    function test_CollectAndShareRevenueSuccessfulIfAuctionNotCollected() public {
        uint256 auctionId0 = 1;
        uint256 auctionId1 = 2;
        setUpMarketplace(auctionId0);
        setUpMarketplace(auctionId1);
        // Collect and share revenue for a single auction.

        // Record balances before payout.
        uint256 balBeforeBen1 = bic.balanceOf(beneficiary1);
        uint256 balBeforeBen2 = bic.balanceOf(beneficiary2);
        uint256 balBeforeCollector = bic.balanceOf(collector);
    
        
        uint256[] memory auctionIds = new uint256[](2);
        auctionIds[0] = auctionId0;
        auctionIds[1] = auctionId1;


        uint256 amount1 = bidAmount * (10000 - 600) / 10000;
        uint256 amount2 = bidAmount * (10000 - 600) / 10000;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        address[][] memory beneficiariesList = new address[][](2);
        address[] memory beneficiaries1 = new address[](2);
        beneficiaries1[0] = beneficiary1;
        beneficiaries1[1] = beneficiary2;
        address[] memory beneficiaries2 = new address[](2);
        beneficiaries2[0] = beneficiary1;
        beneficiaries2[1] = beneficiary2;
        beneficiariesList[0] = beneficiaries1;
        beneficiariesList[1] = beneficiaries2;


        uint256[][] memory collectsList = new uint256[][](2);

        uint256[] memory collects1 = new uint256[](2);
        collects1[0] = 5000;
        collects1[1] = 4000;
        collectsList[0] = collects1;
        uint256[] memory collects2 = new uint256[](2);
        collects2[0] = 5000;
        collects2[1] = 4000;
        collectsList[1] = collects2;

        bool[] memory isAuctionsCollectedList = new bool[](2);
        isAuctionsCollectedList[0] = false;
        isAuctionsCollectedList[1] = false;

        vm.startPrank(controllerAddress);
        controller.batchCollectAndShareRevenue(auctionIds, amounts, beneficiariesList, collectsList, isAuctionsCollectedList);(auctionIds, amounts, beneficiariesList, collectsList, isAuctionsCollectedList);

        // Verify auctionCanClaim has been updated.
        assertFalse(controller.auctionCanClaim(auctionId0), "Auction should not be claimable after revenue collection");
        assertFalse(controller.auctionCanClaim(auctionId1), "Auction should not be claimable after revenue collection");

        // Calculate and verify correct payouts.
        uint256 balAfterBen1 = bic.balanceOf(beneficiary1);
        uint256 balAfterBen2 = bic.balanceOf(beneficiary2);
        uint256 balAfterCollector = bic.balanceOf(collector);

        uint256 totalReceiveBen1 = (amount1 * collects1[0]) / 10000 + (amount2 * collects2[0]) / 10000;
        uint256 totalReceiveBen2 = (amount1 * collects1[1]) / 10000 + (amount2 * collects2[1]) / 10000;

        assertEq(balAfterBen1 - balBeforeBen1, totalReceiveBen1, "Beneficiary1 did not receive the correct amount");
        assertEq(balAfterBen2 - balBeforeBen2, totalReceiveBen2, "Beneficiary2 did not receive the correct amount");

        // No residual funds should remain for the collector in this distribution.
        assertEq(balAfterCollector - balBeforeCollector, amount1 - totalReceiveBen1 + amount2 - totalReceiveBen2, "Collector should receive remaining funds");
    }

    function test_CollectAndShareRevenueSuccessfulIfAuctionCollected() public {
        uint256 auctionId0 = 1;
        uint256 auctionId1 = 2;
        setUpMarketplace(auctionId0);
        setUpMarketplace(auctionId1);
        // Collect and share revenue for a single auction.

        // Record balances before payout.
        uint256 balBeforeBen1 = bic.balanceOf(beneficiary1);
        uint256 balBeforeBen2 = bic.balanceOf(beneficiary2);
        uint256 balBeforeCollector = bic.balanceOf(collector);
    
        
        uint256[] memory auctionIds = new uint256[](2);
        auctionIds[0] = auctionId0;
        auctionIds[1] = auctionId1;


        uint256 amount1 = bidAmount * (10000 - 600) / 10000;
        uint256 amount2 = bidAmount * (10000 - 600) / 10000;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        address[][] memory beneficiariesList = new address[][](2);
        address[] memory beneficiaries1 = new address[](2);
        beneficiaries1[0] = beneficiary1;
        beneficiaries1[1] = beneficiary2;
        address[] memory beneficiaries2 = new address[](2);
        beneficiaries2[0] = beneficiary1;
        beneficiaries2[1] = beneficiary2;
        beneficiariesList[0] = beneficiaries1;
        beneficiariesList[1] = beneficiaries2;


        uint256[][] memory collectsList = new uint256[][](2);

        uint256[] memory collects1 = new uint256[](2);
        collects1[0] = 5000;
        collects1[1] = 4000;
        collectsList[0] = collects1;
        uint256[] memory collects2 = new uint256[](2);
        collects2[0] = 5000;
        collects2[1] = 4000;
        collectsList[1] = collects2;

        bool[] memory isAuctionsCollectedList = new bool[](2);
        isAuctionsCollectedList[0] = false;

        // Case collectPayout external
        mockMarketplace.collectAuctionPayout(auctionId1);
        isAuctionsCollectedList[1] = true;

        vm.startPrank(controllerAddress);
        controller.batchCollectAndShareRevenue(auctionIds, amounts, beneficiariesList, collectsList, isAuctionsCollectedList);

        // Verify auctionCanClaim has been updated.
        assertFalse(controller.auctionCanClaim(auctionId0), "Auction should not be claimable after revenue collection");
        assertFalse(controller.auctionCanClaim(auctionId1), "Auction should not be claimable after revenue collection");

        // Calculate and verify correct payouts.
        uint256 balAfterBen1 = bic.balanceOf(beneficiary1);
        uint256 balAfterBen2 = bic.balanceOf(beneficiary2);
        uint256 balAfterCollector = bic.balanceOf(collector);

        uint256 totalReceiveBen1 = (amount1 * collects1[0]) / 10000 + (amount2 * collects2[0]) / 10000;
        uint256 totalReceiveBen2 = (amount1 * collects1[1]) / 10000 + (amount2 * collects2[1]) / 10000;

        assertEq(balAfterBen1 - balBeforeBen1, totalReceiveBen1, "Beneficiary1 did not receive the correct amount");
        assertEq(balAfterBen2 - balBeforeBen2, totalReceiveBen2, "Beneficiary2 did not receive the correct amount");

        // No residual funds should remain for the collector in this distribution.
        assertEq(balAfterCollector - balBeforeCollector, amount1 - totalReceiveBen1 + amount2 - totalReceiveBen2, "Collector should receive remaining funds");
    }

    function test_RevertIfCollectAndShareRevenue_NotController() public {
        uint256 auctionId = 2;
        setUpMarketplace(auctionId);
        // Attempt to call `collectAndShareRevenue` from a non-controller address.

        uint256[] memory auctionIds = new uint256[](1);
        auctionIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000;

        address[][] memory beneficiariesList = new address[][](1);
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = address(0x1111);
        beneficiariesList[0] = beneficiaries;

        uint256[][] memory collectsList = new uint256[][](1);
        uint256[] memory collects = new uint256[](1);
        collects[0] = 10000; // 100%
        collectsList[0] = collects;

        bool[] memory isAuctionsCollectedList = new bool[](1);
        isAuctionsCollectedList[0] = true;

        address nonControllerAddress = address(0x1234);
        vm.startPrank(nonControllerAddress);
        vm.expectRevert(HandlesController.NotOperator.selector);
        controller.batchCollectAndShareRevenue(auctionIds, amounts, beneficiariesList, collectsList, isAuctionsCollectedList);
        vm.stopPrank();
    }

}
