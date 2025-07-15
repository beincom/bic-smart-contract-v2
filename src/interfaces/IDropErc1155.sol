// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title IDropErc1155
 * @dev Interface for ERC1155 drop contracts with claim phases and access control
 */
interface IDropErc1155 is IERC1155 {
    /// @notice Struct representing a claim phase configuration
    struct ClaimPhase {
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 maxClaimableSupply;
        uint256 supplyClaimed;
        uint256 quantityLimitPerWallet;
        uint256 pricePerToken;
        address currency;
        bytes32 merkleRoot;
        bool isActive;
    }

    /// @notice Struct for claim conditions
    struct ClaimRequest {
        address receiver;
        uint256 tokenId;
        uint256 quantity;
        uint256 pricePerToken;
        address currency;
        bytes32[] proofs;
    }

    /// Events
    event ClaimPhaseUpdated(uint256 indexed tokenId, uint256 indexed phaseId, ClaimPhase phase);
    event TokensClaimed(
        address indexed claimer,
        address indexed receiver,
        uint256 indexed tokenId,
        uint256 phaseId,
        uint256 quantity
    );
    event MaxTotalSupplyUpdated(uint256 indexed tokenId, uint256 maxTotalSupply);
    event DefaultRoyaltyUpdated(address indexed royaltyRecipient, uint256 royaltyBps);
    event TokenURIUpdated(uint256 indexed tokenId, string uri);
    event TokensLazyMinted(uint256 indexed startTokenId, uint256 endTokenId, string[] baseURIs);

    /// Errors
    error DropPhaseNotActive();
    error DropPhaseNotFound();
    error DropExceedsMaxSupply();
    error DropExceedsPhaseSupply();
    error DropExceedsQuantityLimit();
    error DropInvalidProof();
    error DropInvalidPrice();
    error DropInvalidCurrency();
    error DropInvalidTimestamp();
    error DropUnauthorized();

    /// @notice Set claim phase for a token
    function setClaimPhase(uint256 tokenId, uint256 phaseId, ClaimPhase calldata phase) external;

    /// @notice Claim tokens in an active phase
    function claim(ClaimRequest calldata request, uint256 phaseId) external payable;

    /// @notice Get claim phase for a token
    function getClaimPhase(uint256 tokenId, uint256 phaseId) external view returns (ClaimPhase memory);

    /// @notice Get active claim phase for a token
    function getActiveClaimPhase(uint256 tokenId) external view returns (uint256 phaseId, ClaimPhase memory phase);

    /// @notice Verify claim eligibility
    function verifyClaim(
        address claimer,
        ClaimRequest calldata request,
        uint256 phaseId
    ) external view returns (bool isEligible);

    /// @notice Set maximum total supply for a token
    function setMaxTotalSupply(uint256 tokenId, uint256 maxTotalSupply) external;

    /// @notice Get maximum total supply for a token
    function getMaxTotalSupply(uint256 tokenId) external view returns (uint256);

    /// @notice Set default royalty information
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external;

    /// @notice Get total supply of a token
    function totalSupply(uint256 tokenId) external view returns (uint256);

    /// @notice Lazy mint tokens with URIs (increments nextTokenIdToLazyMint)
    function lazyMint(uint256 amount, string[] calldata baseURIs) external;

    /// @notice Get URI for a specific token
    function tokenURI(uint256 tokenId) external view returns (string memory);

    /// @notice Get the next token ID to be lazy minted
    function nextTokenIdToLazyMint() external view returns (uint256);
} 