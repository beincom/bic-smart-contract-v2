// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {IEnglishAuctions, IPlatformFee} from "../interfaces/IMarketplace.sol";
import {IDupHandles} from "../interfaces/IDupHandles.sol";
import {IBicForwarder} from "../interfaces/IBicForwarder.sol";

/**
 * @title HandlesController redesigned for duplicated handles
 * @dev Manages operations related to handle auctions and direct handle requests, including minting and claim payouts.
 * Uses ECDSA for signature verification and integrates with a marketplace for auction functionalities.
 */
contract DupHandlesController is ReentrancyGuard, Ownable {
    using ECDSA for bytes32;
    using EnumerableSet for EnumerableSet.AddressSet;

    enum MintType {
        DIRECT,
        COMMIT,
        AUCTION
    }

    enum ShareRevenueErrorCode {
        AUCTION_NOT_FOUND,
        AUCTION_STILL_ALIVE,
        NO_WINNER,
        INSUFFICIENT_BALANCE_TO_SHARE,
        INVALID_PARAMETERS_LENGTH
    }

    /**
     * @dev Represents a request to create a handle, either through direct sale or auction.
     */
    struct HandleRequest {
        address receiver; // Address to receive the handle.
        address handle; // Contract address of the handle.
        string name; // Name of the handle.
        uint256 price; // Price to be paid for the handle.
        address[] beneficiaries; // Beneficiaries for the handle's payment.
        uint256[] collects; // Shares of the proceeds for each beneficiary.
        uint256 commitDuration; // Duration for which the handle creation can be committed (reserved).
        uint256 buyoutBidAmount; // Buyout bid amount for the auction.
        uint64 timeBufferInSeconds; // Time buffer for the auction.
        uint64 bidBufferBps; // Bid buffer for the auction.
        bool isAuction; // Indicates if the handle request is for an auction.
    }

    /**
     * @dev Represents a request to create a handle, either through direct sale or auction.
     */
    struct MintHandleParameters {
        address to; // Address to receive the handle.
        address handle; // Contract address of the handle.
        address[] beneficiaries; // Beneficiaries for the handle's payment.
        uint256[] collects; // Shares of the proceeds for each beneficiary.
        string name; // Name of the handle.
        uint256 price; // Price to be paid for the handle.
        MintType mintType; //
    }

    /// @notice Address of trusted operators who can sign handle requests and manage revenue distribution.
    EnumerableSet.AddressSet private _operators;
    /// @dev The BIC token contract address.
    IERC20 public bic;
    /// @dev The marketplace contract used for handling auctions.
    address public marketplace;
    /// @dev The forwarder contract used for handling interactions with the BIC token.
    IBicForwarder public forwarder;
    /// @dev The denominator used for calculating beneficiary shares.
    uint256 public collectsDenominator = 10000;
    /// @dev The address of the collector, who receives any residual funds not distributed to beneficiaries.
    address public collector;
    /// @dev Mapping of auctionId to status isClaimed.
    mapping(uint256 => bool) public auctionCanClaim;
    /// @dev Emitted when a handle is minted, providing details of the transaction including the handle address, recipient, name, and price.
    event MintHandle(
        address indexed handle,
        address indexed to,
        string name,
        uint256 tokenId,
        uint256 price,
        MintType mintType
    );
    /// @dev Emitted when a handle is minted, providing details of the transaction including the handle address, recipient, name, and price.
    event ShareRevenue(
        address from,
        address to,
        uint256 amount,
        uint256 tokenId,
        address handle
    );
    /// @dev Emitted when the bic address is updated.
    event SetBic(address indexed bic);
    /// @dev Emitted when the forwarder address is updated.
    event SetForwarder(address indexed forwarder);
    /// @dev Emitted when the marketplace address is updated.
    event SetMarketplace(address indexed marketplace);
    /// @dev Emitted when the collector address is updated.
    event SetCollector(address indexed collector);
    /// @dev Emitted when the collectsDenominator is updated.
    event SetCollectsDenominator(uint256 collectsDenominator);
    /// @dev Emitted when an auction is created, providing details of the auction ID.
    event CreateAuction(uint256 auctionId);
    /// @dev Emitted when a handle is minted but the auction fails due none bid.
    event BurnHandleMintedButAuctionFailed(
        address handle,
        string name,
        uint256 tokenId
    );
    event WithdrawToken(address indexed token, address indexed to, uint256 amount);
    event RemoveOperator(address indexed operator);
    event SetOperator(address indexed operator);


    /// @dev Revert when invalid request handle signature
    error InvalidRequestSignature();
    /// @dev Revert when auction not be claimed
    error AuctionNotClaimable(uint256 auctionId);
    /// @dev Revert when invalid collect auction signature
    error InvalidCollectAuctionSignature();
    /// @dev Revert when bidder address is zero
    error ZeroBidderAddress();
    /// @dev Revert when bidder address is zero
    error ZeroAddress();
    /// @dev Revert when validUntil is invalid
    error InvalidValidUntil(uint256 current, uint256 validUntil);
    /// @dev Revert when validAfter is invalid
    error InvalidValidAfter(uint256 current, uint256 validAfter);
    /// @dev Revert when beneficiaries and collects are not match
    error BeneficiariesAndCollectsLengthNotMatch();
    /// @dev Revert when collectsDenominator is invalid
    error InvalidCollectsDenominator(uint256 totalCollects, uint256 collectsDenominator);
    /// @dev Revert when auction duration is invalid
    error InvalidAuctionDuration();
    /// @dev Revert invalid auction
    error InvalidShareRevenue(ShareRevenueErrorCode eType);
    /// @dev Revert when invalid bid buffer
    error InvalidBidBuffer();
    /// @dev Revert when invalid buyout
    error InvalidBuyout();
    
    error NotOperator();
    error AlreadyOperator();


    /// @notice Ensures that the function is called only by an operator.
    modifier onlyOperator() {
        if (!_operators.contains(_msgSender())) {
            revert NotOperator();
        }
        _;
    }

    /**
     * @notice Initializes the HandlesController contract with the given BIC token address.
     */
    constructor(IERC20 _bic, address _owner) Ownable(_owner) {
        bic = _bic;
    }

    /// @notice Retrieves the operators address.
    /// @dev Retrieves the operators address.
    /// @return The operators address.
    function getOperators() external view returns (address[] memory) {
        return _operators.values();
    }

    /**
     * @notice
     * @dev
     * @param _bic The new BIC address.
     */
    function setBic(address _bic) external onlyOwner {
        bic = IERC20(_bic);
        emit SetBic(_bic);
    }

    /// @notice Sets a new operator address.
    /// @dev Sets a new operator address for the contract with restricted privileges.
    /// @param operator The address of the new operator.
    function setOperator(address operator) external onlyOwner {
        if(_operators.contains(operator)) {
            revert AlreadyOperator();
        }
        _operators.add(operator);
        emit SetOperator(operator);
    }

    /// @notice Removes an operator address.
    /// @dev Removes an operator address for the contract with restricted privileges.
    /// @param operator The address of the operator to remove.
    function removeOperator(address operator) external onlyOwner {
        if(!_operators.contains(operator)) {
            revert NotOperator();
        }
        _operators.remove(operator);
        emit RemoveOperator(operator);
    }

    /**
     * @notice Sets the marketplace contract address used for handling auctions.
     * @dev Can only be set by an operator. Emits a SetMarketplace event upon success.
     * @param _marketplace The address of the Thirdweb Marketplace contract.
     */
    function setMarketplace(address _marketplace) external onlyOwner {
        marketplace = _marketplace;
        emit SetMarketplace(_marketplace);
    }

    /**
     * @notice Updates the denominator used for calculating beneficiary shares.
     * @dev Can only be performed by an operator. This is used to adjust the precision of distributions.
     * @param _collectsDenominator The new denominator value for share calculations.
     */
    function updateCollectsDenominator(
        uint256 _collectsDenominator
    ) external onlyOwner {
        collectsDenominator = _collectsDenominator;
        emit SetCollectsDenominator(_collectsDenominator);
    }

    /**
     * @notice Sets the address of the collector, who receives any residual funds not distributed to beneficiaries.
     * @dev Can only be performed by an operator. This address acts as a fallback for undistributed funds.
     * @param _collector The address of the collector.
     */
    function setCollector(address _collector) external onlyOwner {
        collector = _collector;
        emit SetCollector(_collector);
    }

    /**
     * @notice Sets the forwarder contract address used for handling interactions with the BIC token.
     * @dev Can only be set by an operator. Emits a SetForwarder event upon success.
     * @dev Using to help controller can bid in auction on behalf of a user want to mint handle but end up in case auction.
     * @param _forwarder The address of the BIC forwarder contract.
     */
    function setForwarder(address _forwarder) external onlyOwner {
        forwarder = IBicForwarder(_forwarder);
        emit SetForwarder(_forwarder);
    }

    /**
     * @notice Processes handle requests, supports direct minting or auctions.
     * @dev Validates the request controller's signature, mints handles, or initializes auctions.
     * Handles are minted directly or auctioned based on the request parameters.
     * @param rq The handle request details including receiver, price, and auction settings.
     * @param validUntil The timestamp until when the request is valid.
     * @param validAfter The timestamp after which the request is valid.
     * @param signature The cryptographic signature to validate the request's authenticity.
     */
    function requestHandle(
        HandleRequest calldata rq,
        uint256 validUntil,
        uint256 validAfter,
        bytes calldata signature
    ) external nonReentrant {
        _validateHandleRequest(rq);
        bytes32 dataHash = getRequestHandleOp(rq, validUntil, validAfter);
        if (!_verifySignature(dataHash, signature)) {
            revert InvalidRequestSignature();
        }

        MintHandleParameters memory params = MintHandleParameters({
            to: rq.receiver,
            handle: rq.handle,
            beneficiaries: rq.beneficiaries,
            collects: rq.collects,
            name: rq.name,
            price: rq.price,
            mintType: MintType.DIRECT
        });

        if (rq.commitDuration == 0) {
            // directly mint from handle
            params.mintType = MintType.DIRECT;
            _mintHandle(params);
        } else {
            // auction or commit
            if (rq.isAuction) {
                // auction
                params.to = address(this);
                params.mintType = MintType.AUCTION;
                uint256 tokenId = _mintHandle(params);
                IDupHandles(rq.handle).approve(
                    address(marketplace),
                    tokenId
                );

                IEnglishAuctions.AuctionParameters memory auctionParams;
                auctionParams.assetContract = rq.handle;
                auctionParams.currency = address(bic);
                auctionParams.minimumBidAmount = rq.price;
                auctionParams.buyoutBidAmount = rq.buyoutBidAmount;
                auctionParams.startTimestamp = uint64(block.timestamp);
                auctionParams.endTimestamp = uint64(
                    block.timestamp + rq.commitDuration
                );
                auctionParams.timeBufferInSeconds = rq.timeBufferInSeconds;
                auctionParams.bidBufferBps = rq.bidBufferBps;
                auctionParams.tokenId = tokenId;
                auctionParams.quantity = 1;
                uint256 auctionId = IEnglishAuctions(marketplace).createAuction(auctionParams);
                auctionCanClaim[auctionId] = true;
                emit CreateAuction(auctionId);

                _createBiddingIfNeeded(auctionId, msg.sender, rq.price, 0);
            }
        }
    }

    /**
     * @notice Cron job to collect and share revenue from multiple auctions.
     * @dev Collects the auction payouts and distributes the revenue to the beneficiaries.
     * @param auctionIds The IDs of the auctions in the Thirdweb Marketplace contract.
     * @param amounts The total amounts of Ether or tokens to be distributed to the beneficiaries for each auction.
     * @param beneficiariesList The list of beneficiaries for each auction.
     * @param collectsList The list of collects for each auction.
     */
    function batchCollectAndShareRevenue(
        uint256[] calldata auctionIds,
        uint256[] calldata amounts,
        address[][] calldata beneficiariesList,
        uint256[][] calldata collectsList,
        bool[] calldata isAuctionsCollectedList
    ) external onlyOperator nonReentrant {
        if (
            auctionIds.length != amounts.length ||
            auctionIds.length != beneficiariesList.length ||
            auctionIds.length != collectsList.length ||
            auctionIds.length != isAuctionsCollectedList.length
        ) {
            revert InvalidShareRevenue(ShareRevenueErrorCode.INVALID_PARAMETERS_LENGTH);
        }

        for (uint256 i = 0; i < auctionIds.length; i++) {
            _collectAndShareRevenue(
                auctionIds[i],
                amounts[i],
                beneficiariesList[i],
                collectsList[i],
                isAuctionsCollectedList[i]
            );
        }
    }

    /**
     * @notice Internal function to collect and share revenue for a single auction.
     * @dev Collects the auction payout and distributes the revenue to the beneficiaries.
     * @param auctionId The ID of the auction in the Thirdweb Marketplace contract.
     * @param amount The total amount of Ether or tokens to be distributed to the beneficiaries.
     * @param beneficiaries The beneficiaries for the auction.
     * @param collects The collects for the auction.
     * @param isAuctionCollected The status of the auction payout.
     */
    function _collectAndShareRevenue(
        uint256 auctionId,
        uint256 amount,
        address[] calldata beneficiaries,
        uint256[] calldata collects,
        bool isAuctionCollected
    ) internal {
        _validateCollectAuctionPayout(auctionId, beneficiaries, collects);
        if (!auctionCanClaim[auctionId]) {
            revert AuctionNotClaimable(auctionId);
        }

        IEnglishAuctions.Auction memory auction = IEnglishAuctions(marketplace).getAuction(auctionId);
        if (auction.endTimestamp >= block.timestamp) {
            revert InvalidShareRevenue(ShareRevenueErrorCode.AUCTION_STILL_ALIVE);
        }

        (, address currency, uint256 bidAmount) = IEnglishAuctions(marketplace).getWinningBid(auctionId);
        if (currency != address(bic)) {
            revert InvalidShareRevenue(ShareRevenueErrorCode.NO_WINNER);
        }
        if (bidAmount == 0) {
            revert InvalidShareRevenue(ShareRevenueErrorCode.NO_WINNER);
        }
        if(!isAuctionCollected) {
            IEnglishAuctions(marketplace).collectAuctionPayout(auctionId);
            (, uint16 feeBps) = IPlatformFee(marketplace).getPlatformFeeInfo();
            uint256 finalAmount = (bidAmount * (10000 - feeBps)) / 10000;
            if (finalAmount < amount) {
                revert InvalidShareRevenue(ShareRevenueErrorCode.INSUFFICIENT_BALANCE_TO_SHARE);
            }
        }
        auctionCanClaim[auctionId] = false;
        _payout(amount, beneficiaries, collects, auction.tokenId, auction.assetContract);
    }

    /**
     * @notice Verifies the signature of a transaction.
     * @dev Internal function to verify the signature of a transaction.
     */
    function _verifySignature(
        bytes32 dataHash,
        bytes calldata signature
    ) private view returns (bool) {
        bytes32 dataHashSign = MessageHashUtils.toEthSignedMessageHash(dataHash);
        address signer = dataHashSign.recover(signature);
        return _operators.contains(signer);
    }

    /**
     * @notice Mints handles directly or assigns them to the contract for auction.
     * @dev Internal function to mint handles directly or assign to the contract for auction.
     * @param params The mint handle parameters including the receiver, price, and auction settings.
     */
    function _mintHandle(
        MintHandleParameters memory params
    ) private returns (uint256) {
        address to = params.to;
        address handle = params.handle;
        address[] memory beneficiaries = params.beneficiaries;
        uint256[] memory collects = params.collects;
        string memory name = params.name;
        uint256 price = params.price;
        MintType mintType = params.mintType;
        uint256 tokenId = IDupHandles(handle).mintHandle(to, name);

        if (to != address(this)) {
            IERC20(bic).transferFrom(msg.sender, address(this), price);
            _payout(price, beneficiaries, collects, tokenId, handle);
        }
        
        emit MintHandle(handle, to, name, tokenId, price, mintType);
        return tokenId;
    }

    /**
     * @notice Distributes funds to beneficiaries and a collector.
     * @dev Internal function to distribute funds to beneficiaries and collector.
     * @param amount The total amount to be distributed.
     * @param beneficiaries The addresses of the beneficiaries.
     * @param collects The percentage of the amount to be distributed to each beneficiary.
     */
    function _payout(
        uint256 amount,
        address[] memory beneficiaries,
        uint256[] memory collects,
        uint256 tokenId,
        address handle
    ) private {
        uint256 totalCollects = 0;
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            uint256 collect = (amount * collects[i]) / collectsDenominator;
            IERC20(bic).transfer(beneficiaries[i], collect);
            totalCollects += collect;
            emit ShareRevenue(msg.sender, beneficiaries[i], collect, tokenId, handle);
        }
        if (totalCollects < amount) {
            IERC20(bic).transfer(collector, amount - totalCollects);
        }
    }

    function _validateHandleRequest(
        HandleRequest memory rq
    ) view internal {
        if(rq.receiver == address(0) || rq.handle == address(0)) {
            revert ZeroAddress();
        }
        if (rq.beneficiaries.length != rq.collects.length) {
            revert BeneficiariesAndCollectsLengthNotMatch();
        }
        uint256 totalCollects = 0;
        for (uint256 i = 0; i < rq.collects.length; i++) {
            totalCollects += rq.collects[i];
            if (rq.beneficiaries[i] == address(0)) {
                revert ZeroAddress();
            }
        }
        if (totalCollects > collectsDenominator) {
            revert InvalidCollectsDenominator(totalCollects, collectsDenominator);
        }
        if (rq.isAuction && rq.commitDuration == 0) {
            revert InvalidAuctionDuration();
        }
        bool isValidBuyOut = rq.buyoutBidAmount == 0 || rq.buyoutBidAmount >= rq.price;
        if(!isValidBuyOut) {
            revert InvalidBuyout();
        }
        if(rq.bidBufferBps > 10000) {
            revert InvalidBidBuffer();
        }
    }

    /**
     * @notice Creates a bid in an auction on behalf of a bidder.
     * @dev Internal function to create a bid in an auction on behalf of a bidder.
     * @param auctionId The ID of the auction.
     * @param bidder The address of the bidder.
     * @param bidAmount The amount of the bid.
     * NOTE bidder must approve the marketplace contract to spend the bidAmount before calling this function.
     */
    function _createBiddingIfNeeded(
        uint256 auctionId,
        address bidder,
        uint256 bidAmount,
        uint256 ethValue
    ) private {
        if (bidder == address(0)) {
            revert ZeroBidderAddress();
        }
        // if forwarder is not set, skip
        if (address(forwarder) == address(0)) {
            return;
        }

        IBicForwarder.RequestData memory requestData;
        requestData.from = bidder;
        requestData.to = address(marketplace);
        requestData.data = abi.encodeWithSelector(
            IEnglishAuctions.bidInAuction.selector,
            auctionId,
            bidAmount
        );
        requestData.value = ethValue;
        forwarder.forwardRequest(requestData);
    }

    function _validateCollectAuctionPayout(
        uint256 auctionId,
        address[] calldata beneficiaries,
        uint256[] calldata collects
    ) view internal {
        if(!auctionCanClaim[auctionId]) {
            revert AuctionNotClaimable(auctionId);
        }
        if(beneficiaries.length != collects.length) {
            revert BeneficiariesAndCollectsLengthNotMatch();
        }
        uint256 totalCollects = 0;
        for (uint256 i = 0; i < collects.length; i++) {
            totalCollects += collects[i];
            if (beneficiaries[i] == address(0)) {
                revert ZeroAddress();
            }
        }
        if (totalCollects > collectsDenominator) {
            revert InvalidCollectsDenominator(totalCollects, collectsDenominator);
        }
    }

    /**
     * @notice Allows withdrawal of funds or tokens from the contract.
     * @param token The address of the token to withdraw
     * @param to The recipient of the funds or tokens.
     * @param amount The amount to withdraw.
     * @dev no need to withdraw ETH because this contract not have fallback or receive function
     */
    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        bool success;
        if (token == address(0)) {
            (success, ) = address(to).call{value: amount}("");
        } else {
            success = IERC20(token).transfer(to, amount);
        }
        emit WithdrawToken(token, to, amount);

    }

    /**
     * @notice Allows the operator to claim tokens sent to the contract by mistake.
     * @dev Generates a unique hash for a handle request operation based on multiple parameters.
     * @dev if tx is commit, its require commit duration > validUntil - validAfter because requirement can flexibly collects and beneficiaries
     * @param rq The handle request details including receiver, price, and auction settings.
     * @param validUntil The timestamp until when the request is valid.
     * @param validAfter The timestamp after when the request is valid.
     * @return The unique hash for the handle request operation.
     */
    function getRequestHandleOp(
        HandleRequest calldata rq,
        uint256 validUntil,
        uint256 validAfter
    ) public view returns (bytes32) {
        {
            if (block.timestamp > validUntil) {
                revert InvalidValidUntil(block.timestamp, validUntil);
            }
            if (block.timestamp <= validAfter) {
                revert InvalidValidAfter(block.timestamp, validAfter);
            }
            if (rq.beneficiaries.length != rq.collects.length) {
                revert BeneficiariesAndCollectsLengthNotMatch();
            }
        }

        return
            keccak256(
                abi.encode(
                    rq.receiver,
                    rq.handle,
                    rq.name,
                    rq.price,
                    rq.beneficiaries,
                    rq.collects,
                    block.chainid,
                    validUntil,
                    validAfter
                )
            );
    }
}
