// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IEnglishAuctions, IPlatformFee} from "../../../src/interfaces/IMarketplace.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockMarketplace {
    IEnglishAuctions.Auction public auction;
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
        auction = IEnglishAuctions.Auction({
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
    
    function setWinningBid(uint256, address _bidder, uint256 _bidAmount) external {
        // For simplicity we ignore _auctionId.
        winningBidder = _bidder;
        bidAmount = _bidAmount;
    }
    
    function createAuction(IEnglishAuctions.AuctionParameters memory) external pure returns (uint256) {
        return 0;
    }
    
    function getAuction(uint256) external view returns (IEnglishAuctions.Auction memory) {
        return auction;
    }
    
    function getWinningBid(uint256) external view returns (address, address, uint256) {
        return (winningBidder, auction.currency, bidAmount);
    }
    
    function collectAuctionPayout(uint256) external {
        // No-operation for testing.
        ERC20(auction.currency).transfer(auction.auctionCreator, bidAmount * (10000 - feeBps) / 10000);
        
    }
    
    // IPlatformFee implementation.
    function getPlatformFeeInfo() external view returns (address, uint16) {
        return (address(this), feeBps);
    }
}
