// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;


import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";


import {IEnglishAuctions} from "../interfaces/IMarketplace.sol";
import {IHandles} from "../interfaces/IHandles.sol";
import {IBicForwarder} from "../interfaces/IBicForwarder.sol";

/**
 * @title HandlesController
 * @dev Manages operations related to handle auctions and direct handle requests, including minting and claim payouts.
 * Uses ECDSA for signature verification and integrates with a marketplace for auction functionalities.
 */
contract HandlesController is ReentrancyGuard, Ownable {
    using ECDSA for bytes32;

    enum MintType {
        DIRECT,
        COMMIT,
        AUCTION
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
        uint256 tokenId; // Token ID of the handle.
        string name; // Name of the handle.
        uint256 price; // Price to be paid for the handle.
        MintType mintType; //
    }



    /// @dev The address of the verifier authorized to validate signatures.
    address public verifier;
    /// @dev The BIC token contract address.
    IERC20 public bic;
    /// @dev Mapping of commitments to their respective expiration timestamps. Used to manage the timing of commitments and auctions.
    mapping(bytes32 => uint256) public commitments;
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
        uint256 price,
        MintType mintType
    );
    /// @dev Emitted when a commitment is made, providing details of the commitment and its expiration timestamp.
    event Commitment(
        bytes32 indexed commitment,
        address from,
        address collection,
        string name,
        uint256 tokenId,
        uint256 price,
        uint256 endTimestamp,
        bool isClaimed
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
    /// @dev Emitted when the verifier address is updated.
    event SetVerifier(address indexed verifier);
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
    /// @dev Revert when assetContract is zero
    error ZeroAssetContract();
    /// @dev Revert when invalid bid buffer
    error InvalidBidBuffer();
    /// @dev Revert when invalid buyout
    error InvalidBuyout();
    /// @dev Revert when invalid auction
    error InvalidAuction();

    /**
     * @notice Initializes the HandlesController contract with the given BIC token address.
     */
    constructor(IERC20 _bic, address _owner) Ownable(_owner) {
        bic = _bic;
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

    /**
     * @notice Sets a new verifier address authorized to validate signatures.
     * @dev Can only be set by an operator. Emits a SetVerifier event upon success.
     * @param _verifier The new verifier address.
     */
    function setVerifier(address _verifier) external onlyOwner {
        verifier = _verifier;
        emit SetVerifier(_verifier);
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
     * @dev Validates the request verifier's signature, mints handles, or initializes auctions.
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

        uint256 tokenId = IHandles(rq.handle).getTokenId(rq.name);
        MintHandleParameters memory params = MintHandleParameters({
            to: rq.receiver,
            handle: rq.handle,
            beneficiaries: rq.beneficiaries,
            collects: rq.collects,
            tokenId: tokenId,
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
                _mintHandle(params);
                IHandles(rq.handle).approve(
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
                auctionParams.tokenId = IHandles(rq.handle).getTokenId(rq.name);
                auctionParams.quantity = 1;
                uint256 auctionId = IEnglishAuctions(marketplace).createAuction(auctionParams);
                auctionCanClaim[auctionId] = true;
                emit CreateAuction(auctionId);

                _createBiddingIfNeeded(auctionId, msg.sender, rq.price, 0);
            } else {
                // commit
                bool isCommitted = _isCommitted(dataHash, rq);
                if (!isCommitted) {
                    params.mintType = MintType.COMMIT;
                    _mintHandle(
                        params
                    );
                    _emitCommitment(rq, dataHash, 0, true);
                }
            }
        }
    }

    /**
     * @notice Collects the auction payouts after an auction concludes in the Thirdweb Marketplace. [LINK]: https://github.com/thirdweb-dev/contracts/tree/main/contracts/prebuilts/marketplace/english-auctions
     * @dev This function is called after a successful auction on the Thirdweb Marketplace to distribute the auction proceeds.
     *      The process involves two main steps:
     *
     *      1. The winning bidder claims the auction amount through the Thirdweb Marketplace contract, which transfers the funds to this HandleController contract.
     *
     *      2. This function is then called to distribute these funds among the predefined beneficiaries according to the specified shares.
     *
     *      This function ensures that only valid, unclaimed auctions can be processed and verifies the operation via signature.
     *
     *      It checks that the auction was marked as claimable, verifies the provided signature to ensure it comes from a valid source, and then performs the payout.
     *
     *      Once the payout is completed, it marks the auction as claimed to prevent re-claiming.
     *
     * @param auctionId The ID of the auction in the Thirdweb Marketplace contract.
     * @param amount The total amount of Ether or tokens to be distributed to the beneficiaries.
     * @param signature The signature from the authorized verifier to validate the claim operation.
     *
     * @notice The function will revert if:
     *
     *      - The auction associated with the handle is not marked as canClaim.
     *      - The provided signature does not validate against the expected payload signed by the authorized signer.
     */
    function collectAuctionPayout(
        uint256 auctionId,
        uint256 amount,
        address[] calldata beneficiaries,
        uint256[] calldata collects,
        bytes calldata signature
    ) external nonReentrant {
        _validateCollectAuctionPayout(auctionId, beneficiaries, collects);
        bytes32 dataHash = getCollectAuctionPayoutOp(
            auctionId,
            amount,
            beneficiaries,
            collects
        );
        if(!_verifySignature(dataHash, signature)) {
            revert InvalidCollectAuctionSignature();
        }
        IEnglishAuctions.Auction memory auction = IEnglishAuctions(marketplace).getAuction(auctionId);
        _validateValidAuction(auction);
        _payout(amount, beneficiaries, collects, auction.tokenId, auction.assetContract);
        auctionCanClaim[auctionId] = false;
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
        return signer == verifier;
    }

    /**
     * @notice Handles commitments for minting handles with a delay.
     * @dev Internal function to handle commitments for minting handles with a delay.
     * @param commitment The hash of the commitment.
     * @param rq The handle request details including receiver, price, and auction settings.
     */
    function _isCommitted(
        bytes32 commitment,
        HandleRequest calldata rq
    ) private returns (bool) {
        if (commitments[commitment] != 0) {
            if (commitments[commitment] < block.timestamp) {
                return false;
            }
        } else {
            // User commited
            commitments[commitment] = block.timestamp + rq.commitDuration;
            // Emit event for once time user commited
            _emitCommitment(rq, commitment, commitments[commitment], false);
        }
        return true;
    }

    /**
     * @notice Handles commitments for minting handles with a delay.
     * @dev Internal function to handle commitments for minting handles with a delay.
     * @dev Three cases, decision to mint handle is based on user's request and BIC back-end logic:
        *      1. User want a NFT and can mint directly buy using BIC
        *      2. User want a NFT but cannot mint directly, so user commit to mint NFT
        *      3. User want a NFT but cannot mint directly, and nether can commit it. So controller mint NFT and put it in auction
     * @param rq The handle request details including receiver, price, and auction settings.
     * @param _dataHash The hash committment
     * @param _isClaimed The status of claim
     */
    function _emitCommitment(
        HandleRequest memory rq,
        bytes32 _dataHash,
        uint256 endTime,
        bool _isClaimed
    ) internal {
        uint256 tokenId = IHandles(rq.handle).getTokenId(rq.name);
        emit Commitment(
            _dataHash,
            msg.sender,
            rq.handle,
            rq.name,
            tokenId,
            rq.price,
            endTime,
            _isClaimed
        );
    }

    /**
     * @notice Mints handles directly or assigns them to the contract for auction.
     * @dev Internal function to mint handles directly or assign to the contract for auction.
     * @param params The mint handle parameters including the receiver, price, and auction settings.
     */
    function _mintHandle(
        MintHandleParameters memory params
    ) private {
        address to = params.to;
        address handle = params.handle;
        address[] memory beneficiaries = params.beneficiaries;
        uint256[] memory collects = params.collects;
        uint256 tokenId = params.tokenId;
        string memory name = params.name;
        uint256 price = params.price;
        MintType mintType = params.mintType;

        if (to != address(this)) {
            IERC20(bic).transferFrom(msg.sender, address(this), price);
            _payout(price, beneficiaries, collects, tokenId, handle);
        }
        IHandles(handle).mintHandle(to, name);
        emit MintHandle(handle, to, name, price, mintType);
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

    function _validateHandleRequest(
        HandleRequest memory rq
    ) view internal {
        if(rq.receiver == address(0)) {
            revert ZeroAddress();
        }
        if(rq.handle == address(0)) {
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

    function _validateCollectAuctionPayout(
        uint256 auctionId,
        address[] calldata beneficiaries,
        uint256[] calldata collects
    ) view internal {
        if(!auctionCanClaim[auctionId]) {
            revert AuctionNotClaimable(auctionId);
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

    function _validateValidAuction(
        IEnglishAuctions.Auction memory auction
        // uint256 sharedAmount
    ) view internal {
        if(auction.assetContract == address(0)) {
            revert ZeroAssetContract();
        }
        if(auction.endTimestamp > block.timestamp) {
            revert InvalidAuction();
        }

        // Make sure the auction has winner
        (address bidder, ,) = IEnglishAuctions(marketplace).getWinningBid(auction.auctionId);
        if(bidder == address(0)) {
            revert InvalidAuction();
        }
        // Actual wining bid amount must to greater than or equal to amount shared revenue
        // Should not check this condition because it can be flexible to collect by Service instead of FE
        // if(bidAmount < sharedAmount) {
        //     revert InvalidAuction();
        // }
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
        IERC20(token).transfer(to, amount);
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
        if (rq.commitDuration > 0 && !rq.isAuction) {
            return
                keccak256(
                    abi.encode(
                        rq.receiver,
                        rq.handle,
                        rq.name,
                        rq.price,
                        rq.commitDuration,
                        rq.isAuction,
                        block.chainid
                    )
                );
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

    /**
     * @notice Generates a unique hash for a collect auction payout operation.
     * @dev Generates a unique hash for a collect auction payout operation.
     */
    function getCollectAuctionPayoutOp(
        uint256 auctionId,
        uint256 amount,
        address[] calldata beneficiaries,
        uint256[] calldata collects
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    auctionId,
                    amount,
                    block.chainid,
                    beneficiaries,
                    collects
                )
            );
    }

    /**
     * @notice Allows the operator to burn a handle that was minted when case the auction failed (none bid).
     * @param handle The address of the handle contract.
     * @param name The name of the handle.
     */
    function burnHandleMintedButAuctionFailed(
        address handle,
        string calldata name
    ) external onlyOwner {
        uint256 tokenId = IHandles(handle).getTokenId(name);
        IHandles(handle).burn(tokenId);
        emit BurnHandleMintedButAuctionFailed(handle, name, tokenId);
    }
}
