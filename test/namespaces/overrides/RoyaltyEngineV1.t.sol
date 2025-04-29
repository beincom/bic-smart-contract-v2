// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../../src/overrides/RoyaltyEngineV1.sol";
import "../mocks/MockMarketplace.t.sol";
import "../mocks/TestBIC.t.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Mock ERC721 with royalty implementation
contract MockERC721WithRoyalty is ERC721 {
    uint256 private _royaltyAmount;
    address private _royaltyRecipient;

    constructor(address royaltyRecipient, uint256 royaltyPercentage) ERC721("MockNFT", "MNFT") {
        _royaltyRecipient = royaltyRecipient;
        _royaltyAmount = royaltyPercentage;
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function royaltyInfo(uint256, uint256 salePrice) external view returns (address, uint256) {
        return (_royaltyRecipient, (salePrice * _royaltyAmount) / 10000);
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == 0x2a55205a || super.supportsInterface(interfaceId); // IERC2981 interface ID
    }
}

contract RoyaltyEngineV1Test is Test {
    RoyaltyEngineV1 public royaltyEngine;
    MockMarketplace public marketplace;
    TestBIC public bicToken;
    MockERC721WithRoyalty public nft;

    address public seller;
    address public buyer;
    address public royaltyRecipient;

    uint256 public constant TOKEN_ID = 1;
    uint256 public constant BID_AMOUNT = 1000 * 10**18;
    uint256 public constant ROYALTY_BPS = 1000; // 10%

    function setUp() public {
        // Set up accounts
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        royaltyRecipient = makeAddr("royaltyRecipient");

        // Deploy contracts
        royaltyEngine = new RoyaltyEngineV1();
        marketplace = new MockMarketplace();
        bicToken = new TestBIC();
        nft = new MockERC721WithRoyalty(royaltyRecipient, ROYALTY_BPS);

        // Mint NFT to seller
        nft.mint(seller, TOKEN_ID);

        // Mint BIC tokens to buyer
        bicToken.mint(buyer, BID_AMOUNT * 2);

        // Set royalty engine in marketplace
        marketplace.setRoyaltyEngine(address(royaltyEngine));

        // Send some BIC to the marketplace to simulate buyer's funds
        vm.startPrank(buyer);
        bicToken.transfer(address(marketplace), BID_AMOUNT);
        vm.stopPrank();
    }

    function testSupportsInterface() public {
        assertTrue(royaltyEngine.supportsInterface(type(IRoyaltyEngineV1).interfaceId));
        assertTrue(royaltyEngine.supportsInterface(0x01ffc9a7)); // ERC165 interface ID
    }

    function testGetRoyalty() public {
        uint256 expectedRoyaltyAmount = (BID_AMOUNT * ROYALTY_BPS) / 10000; // 10% of bid amount

        (address payable[] memory recipients, uint256[] memory amounts) = royaltyEngine.getRoyalty(
            address(nft),
            TOKEN_ID,
            BID_AMOUNT
        );

        assertEq(recipients.length, 1, "Should have one royalty recipient");
        assertEq(amounts.length, 1, "Should have one royalty amount");
        assertEq(address(recipients[0]), royaltyRecipient, "Incorrect royalty recipient");
        assertEq(amounts[0], expectedRoyaltyAmount, "Incorrect royalty amount");
    }

    function testGetRoyaltyView() public {
        uint256 expectedRoyaltyAmount = (BID_AMOUNT * ROYALTY_BPS) / 10000; // 10% of bid amount

        (address payable[] memory recipients, uint256[] memory amounts) = royaltyEngine.getRoyaltyView(
            address(nft),
            TOKEN_ID,
            BID_AMOUNT
        );

        assertEq(recipients.length, 1, "Should have one royalty recipient");
        assertEq(amounts.length, 1, "Should have one royalty amount");
        assertEq(address(recipients[0]), royaltyRecipient, "Incorrect royalty recipient");
        assertEq(amounts[0], expectedRoyaltyAmount, "Incorrect royalty amount");
    }

    function testMarketplaceIntegration() public {
        // Set up auction
        uint256 auctionId = 1;
        uint64 endTimestamp = uint64(block.timestamp + 1 days);
        
        marketplace.setAuction(
            auctionId,
            address(nft),
            address(bicToken),
            seller,
            TOKEN_ID,
            endTimestamp
        );
        
        // Set winning bid
        marketplace.setWinningBid(auctionId, buyer, BID_AMOUNT);
        
        // Check royalty recipient's balance before collection
        uint256 royaltyRecipientBalanceBefore = bicToken.balanceOf(royaltyRecipient);
        uint256 sellerBalanceBefore = bicToken.balanceOf(seller);
        
        // Collect payout
        marketplace.collectAuctionPayout(auctionId);
        
        // Calculate expected royalty
        uint256 expectedRoyaltyAmount = (BID_AMOUNT * (10000 - 600) / 10000) * ROYALTY_BPS / 10000; // Platform fee 6%, then 10% royalty
        uint256 expectedSellerAmount = (BID_AMOUNT * (10000 - 600) / 10000) - expectedRoyaltyAmount; // Remaining after platform fee and royalty
        
        // Check balances after collection
        uint256 royaltyRecipientBalanceAfter = bicToken.balanceOf(royaltyRecipient);
        uint256 sellerBalanceAfter = bicToken.balanceOf(seller);
        
        assertEq(
            royaltyRecipientBalanceAfter - royaltyRecipientBalanceBefore,
            expectedRoyaltyAmount,
            "Royalty recipient should receive correct amount"
        );
        
        assertEq(
            sellerBalanceAfter - sellerBalanceBefore,
            expectedSellerAmount,
            "Seller should receive remaining amount after fees and royalties"
        );
    }

    function testInvalidRoyaltyAmount() public {
        // Create a mock NFT with 100% royalty (invalid)
        MockERC721WithRoyalty invalidNft = new MockERC721WithRoyalty(royaltyRecipient, 10000); // 100%
        invalidNft.mint(seller, 2);

        // Get royalty should still work but return empty arrays
        (address payable[] memory recipients, uint256[] memory amounts) = royaltyEngine.getRoyaltyView(
            address(invalidNft),
            2,
            BID_AMOUNT
        );

        assertEq(recipients.length, 0, "Should have no royalty recipients for invalid royalty");
        assertEq(amounts.length, 0, "Should have no royalty amounts for invalid royalty");
    }

    function testNonERC2981Token() public {
        // Test with a token that doesn't implement ERC2981
        (address payable[] memory recipients, uint256[] memory amounts) = royaltyEngine.getRoyalty(
            address(bicToken), // ERC20 token doesn't implement ERC2981
            1,
            BID_AMOUNT
        );

        assertEq(recipients.length, 0, "Should have no royalty recipients for non-ERC2981 token");
        assertEq(amounts.length, 0, "Should have no royalty amounts for non-ERC2981 token");
    }
}
