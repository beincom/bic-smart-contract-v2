// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IEnglishAuctions, IPlatformFee} from "../../../src/interfaces/IMarketplace.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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
        // No-operation for testing.
        IEnglishAuctions.Auction memory auction = auctions[auctionId];
        Winner memory winner = winningBids[auctionId];
        ERC20(auction.currency).transfer(auction.auctionCreator, winner.bidAmount * (10000 - feeBps) / 10000);
        
    }
    
    // IPlatformFee implementation.
    function getPlatformFeeInfo() external view returns (address, uint16) {
        return (address(this), feeBps);
    }
}
