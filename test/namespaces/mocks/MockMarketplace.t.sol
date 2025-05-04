// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IEnglishAuctions, IPlatformFee} from "../../../src/interfaces/IMarketplace.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "../../../src/interfaces/IRoyaltyEngineV1.sol";

contract MockMarketplace {
    IEnglishAuctions.Auction public auction;
    struct Winner {
        address bidder;
        uint256 bidAmount;
    }
    mapping(uint256 => IEnglishAuctions.Auction) public auctions;
    mapping(uint256 => Winner) public winningBids;
    uint256 public auctionId;
    address public winningBidder;
    uint256 public bidAmount;
    uint16 public feeBps;
    address private _royaltyEngineAddress;

    constructor() {
        feeBps = 600; // 6% fee (600 basis points)
    }
    
    function setAuction(
        uint256 _auctionId,
        address _assetContract,
        address _currency,
        address _auctionCreator,
        uint256 _tokenId,
        uint64 _endTimestamp
    ) external {
        auctionId = _auctionId;
        auctions[auctionId] = IEnglishAuctions.Auction({
            auctionId: _auctionId,
            tokenId: _tokenId,
            quantity: 1,
            minimumBidAmount: 0,
            buyoutBidAmount: 0,
            timeBufferInSeconds: 0,
            bidBufferBps: 0,
            startTimestamp: 0,
            endTimestamp: _endTimestamp,
            auctionCreator: _auctionCreator,
            assetContract: _assetContract,
            currency: _currency,
            tokenType: IEnglishAuctions.TokenType.ERC721,
            status: IEnglishAuctions.Status.CREATED
        });
    }
    
    function setWinningBid(uint256 auctionId, address _bidder, uint256 _bidAmount) external {
        // For simplicity we ignore _auctionId.
        winningBids[auctionId] = Winner(_bidder, _bidAmount);
    }
    
    function createAuction(IEnglishAuctions.AuctionParameters memory) external pure returns (uint256) {
        return 0;
    }
    
    function getAuction(uint256 auctionId) external view returns (IEnglishAuctions.Auction memory) {
        return auctions[auctionId];
    }
    
    function getWinningBid(uint256 auctionId) external view returns (address, address, uint256) {
        IEnglishAuctions.Auction memory auction = auctions[auctionId];
        Winner memory winner = winningBids[auctionId];
        return (winner.bidder, auction.currency, winner.bidAmount);
    }
    
    function collectAuctionPayout(uint256 auctionId) external {
        address royaltyEngineAddress = getRoyaltyEngineAddress();

        // No-operation for testing.
        IEnglishAuctions.Auction memory auction = auctions[auctionId];
        Winner memory winner = winningBids[auctionId];
        uint256 _totalPayoutAmount =  winner.bidAmount * (10000 - feeBps) / 10000;

        (address payable[] memory recipients, uint256[] memory amounts) = getRoyalty(auction.assetContract, auction.tokenId, _totalPayoutAmount);
        uint256 amountRemaining = _totalPayoutAmount;
        uint256 royaltyRecipientCount = recipients.length;

        if (royaltyRecipientCount != 0) {
               uint256 royaltyCut;
                address royaltyRecipient;

                for (uint256 i = 0; i < royaltyRecipientCount; ) {
                    royaltyRecipient = recipients[i];
                    royaltyCut = amounts[i];

                    // Check payout amount remaining is enough to cover royalty payment
                    require(amountRemaining >= royaltyCut, "fees exceed the price");

                    // Transfer royalty
                    ERC20(auction.currency).transfer(royaltyRecipient, royaltyCut);

                    unchecked {
                        amountRemaining -= royaltyCut;
                        ++i;
                    }
                }
        }
        ERC20(auction.currency).transfer(auction.auctionCreator, amountRemaining);
        
    }
    
    // IPlatformFee implementation.
    function getPlatformFeeInfo() external view returns (address, uint16) {
        return (address(this), feeBps);
    }

    function getRoyalty(
        address tokenAddress,
        uint256 tokenId,
        uint256 value
    ) public returns (address payable[] memory recipients, uint256[] memory amounts) {
        address royaltyEngineAddress = getRoyaltyEngineAddress();

        if (royaltyEngineAddress == address(0)) {
            try IERC2981(tokenAddress).royaltyInfo(tokenId, value) returns (address recipient, uint256 amount) {
                require(amount < value, "Invalid royalty amount");

                recipients = new address payable[](1);
                amounts = new uint256[](1);
                recipients[0] = payable(recipient);
                amounts[0] = amount;
            } catch {}
        } else {
            (recipients, amounts) = IRoyaltyEngineV1(royaltyEngineAddress).getRoyalty(tokenAddress, tokenId, value);
        }
    }

    function getRoyaltyEngineAddress() public view returns (address royaltyEngineAddress) {
        return _royaltyEngineAddress;
    }

    function setRoyaltyEngine(address _royaltyEngineAddress) external {

        require(
            _royaltyEngineAddress != address(0) &&
                IERC165(_royaltyEngineAddress).supportsInterface(type(IRoyaltyEngineV1).interfaceId),
            "Doesn't support IRoyaltyEngineV1 interface"
        );

        _royaltyEngineAddress = _royaltyEngineAddress;
    }
}
