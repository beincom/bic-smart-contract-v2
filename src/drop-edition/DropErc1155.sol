// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IDropErc1155} from "../interfaces/IDropErc1155.sol";

/**
 * @title DropErc1155
 * @dev ERC1155 contract with drop functionality including claim phases and merkle tree allowlists
 */
contract DropErc1155 is ERC1155, ERC1155Supply, ERC2981, Ownable, ReentrancyGuard, IDropErc1155 {
    using SafeERC20 for IERC20;

    /// @notice Mapping from token ID to phase ID to claim phase
    mapping(uint256 => mapping(uint256 => ClaimPhase)) public claimPhases;

    /// @notice Mapping from token ID to max total supply
    mapping(uint256 => uint256) public maxTotalSupply;

    /// @notice Mapping from claimer to token ID to phase ID to claimed quantity
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) public claimedByWallet;

    /// @notice Mapping from token ID to token URI
    mapping(uint256 => string) private _tokenURIs;

    /// @notice The next token ID to be lazy minted
    uint256 public nextTokenIdToLazyMint;

    /// @notice Primary sale recipient for primary sales
    address public primarySaleRecipient;

    constructor(
        string memory uri_,
        address owner_,
        address primarySaleRecipient_
    ) ERC1155(uri_) Ownable(owner_) {
        primarySaleRecipient = primarySaleRecipient_;
        nextTokenIdToLazyMint = 0; // Start lazy minting from token ID 0
    }

    /**
     * @notice Set claim phase for a token
     * @param tokenId The token ID
     * @param phaseId The phase ID
     * @param phase The claim phase configuration
     */
    function setClaimPhase(
        uint256 tokenId,
        uint256 phaseId,
        ClaimPhase calldata phase
    ) external override onlyOwner {
        if (phase.startTimestamp >= phase.endTimestamp && phase.endTimestamp != 0) {
            revert DropInvalidTimestamp();
        }

        claimPhases[tokenId][phaseId] = phase;
        emit ClaimPhaseUpdated(tokenId, phaseId, phase);
    }

    /**
     * @notice Claim tokens in an active phase
     * @param request The claim request details
     * @param phaseId The phase ID to claim in
     */
    function claim(
        ClaimRequest calldata request,
        uint256 phaseId
    ) external payable override nonReentrant {
        ClaimPhase storage phase = claimPhases[request.tokenId][phaseId];
        
        // Verify phase is active
        if (!phase.isActive) revert DropPhaseNotActive();
        if (block.timestamp < phase.startTimestamp) revert DropPhaseNotActive();
        if (phase.endTimestamp != 0 && block.timestamp > phase.endTimestamp) revert DropPhaseNotActive();

        // Verify supply limits
        if (maxTotalSupply[request.tokenId] > 0) {
            if (totalSupply(request.tokenId) + request.quantity > maxTotalSupply[request.tokenId]) {
                revert DropExceedsMaxSupply();
            }
        }

        if (phase.maxClaimableSupply > 0) {
            if (phase.supplyClaimed + request.quantity > phase.maxClaimableSupply) {
                revert DropExceedsPhaseSupply();
            }
        }

        // Verify wallet quantity limit
        if (phase.quantityLimitPerWallet > 0) {
            uint256 newClaimedAmount = claimedByWallet[msg.sender][request.tokenId][phaseId] + request.quantity;
            if (newClaimedAmount > phase.quantityLimitPerWallet) {
                revert DropExceedsQuantityLimit();
            }
            claimedByWallet[msg.sender][request.tokenId][phaseId] = newClaimedAmount;
        }

        // Verify merkle proof if required
        if (phase.merkleRoot != bytes32(0)) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender, request.quantity));
            if (!MerkleProof.verify(request.proofs, phase.merkleRoot, leaf)) {
                revert DropInvalidProof();
            }
        }

        // Verify price and currency
        if (request.pricePerToken != phase.pricePerToken) revert DropInvalidPrice();
        if (request.currency != phase.currency) revert DropInvalidCurrency();

        // Handle payment
        uint256 totalPrice = request.pricePerToken * request.quantity;
        if (phase.currency == address(0)) {
            // ETH payment
            if (msg.value != totalPrice) revert DropInvalidPrice();
            if (totalPrice > 0) {
                (bool success,) = payable(primarySaleRecipient).call{value: totalPrice}("");
                require(success, "Transfer failed");
            }
        } else {
            // ERC20 payment
            if (msg.value != 0) revert DropInvalidPrice();
            if (totalPrice > 0) {
                IERC20(phase.currency).safeTransferFrom(msg.sender, primarySaleRecipient, totalPrice);
            }
        }

        // Update phase supply
        phase.supplyClaimed += request.quantity;

        // Mint tokens
        _mint(request.receiver, request.tokenId, request.quantity, "");

        emit TokensClaimed(msg.sender, request.receiver, request.tokenId, phaseId, request.quantity);
    }

    /**
     * @notice Get claim phase for a token
     * @param tokenId The token ID
     * @param phaseId The phase ID
     * @return The claim phase
     */
    function getClaimPhase(
        uint256 tokenId,
        uint256 phaseId
    ) external view override returns (ClaimPhase memory) {
        return claimPhases[tokenId][phaseId];
    }

    /**
     * @notice Get active claim phase for a token
     * @param tokenId The token ID
     * @return phaseId The active phase ID
     * @return phase The active claim phase
     */
    function getActiveClaimPhase(
        uint256 tokenId
    ) external view override returns (uint256 phaseId, ClaimPhase memory phase) {
        uint256 currentTime = block.timestamp;
        
        // Check up to 100 phases (reasonable limit)
        for (uint256 i = 0; i < 100; i++) {
            ClaimPhase memory currentPhase = claimPhases[tokenId][i];
            if (!currentPhase.isActive) continue;
            
            if (currentTime >= currentPhase.startTimestamp &&
                (currentPhase.endTimestamp == 0 || currentTime <= currentPhase.endTimestamp)) {
                return (i, currentPhase);
            }
        }
        
        revert DropPhaseNotFound();
    }

    /**
     * @notice Verify claim eligibility
     * @param claimer The address attempting to claim
     * @param request The claim request
     * @param phaseId The phase ID
     * @return isEligible Whether the claim is eligible
     */
    function verifyClaim(
        address claimer,
        ClaimRequest calldata request,
        uint256 phaseId
    ) external view override returns (bool isEligible) {
        ClaimPhase memory phase = claimPhases[request.tokenId][phaseId];
        
        // Check phase is active
        if (!phase.isActive) return false;
        if (block.timestamp < phase.startTimestamp) return false;
        if (phase.endTimestamp != 0 && block.timestamp > phase.endTimestamp) return false;

        // Check supply limits
        if (maxTotalSupply[request.tokenId] > 0) {
            if (totalSupply(request.tokenId) + request.quantity > maxTotalSupply[request.tokenId]) {
                return false;
            }
        }

        if (phase.maxClaimableSupply > 0) {
            if (phase.supplyClaimed + request.quantity > phase.maxClaimableSupply) {
                return false;
            }
        }

        // Check wallet quantity limit
        if (phase.quantityLimitPerWallet > 0) {
            uint256 newClaimedAmount = claimedByWallet[claimer][request.tokenId][phaseId] + request.quantity;
            if (newClaimedAmount > phase.quantityLimitPerWallet) {
                return false;
            }
        }

        // Check merkle proof if required
        if (phase.merkleRoot != bytes32(0)) {
            bytes32 leaf = keccak256(abi.encodePacked(claimer, request.quantity));
            if (!MerkleProof.verify(request.proofs, phase.merkleRoot, leaf)) {
                return false;
            }
        }

        // Check price and currency
        if (request.pricePerToken != phase.pricePerToken) return false;
        if (request.currency != phase.currency) return false;

        return true;
    }

    /**
     * @notice Set maximum total supply for a token
     * @param tokenId The token ID
     * @param _maxTotalSupply The maximum total supply
     */
    function setMaxTotalSupply(uint256 tokenId, uint256 _maxTotalSupply) external override onlyOwner {
        maxTotalSupply[tokenId] = _maxTotalSupply;
        emit MaxTotalSupplyUpdated(tokenId, _maxTotalSupply);
    }

    /**
     * @notice Get maximum total supply for a token
     * @param tokenId The token ID
     * @return The maximum total supply
     */
    function getMaxTotalSupply(uint256 tokenId) external view override returns (uint256) {
        return maxTotalSupply[tokenId];
    }

    /**
     * @notice Set default royalty information
     * @param receiver The royalty receiver
     * @param feeNumerator The royalty fee numerator (out of 10000)
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external override onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
        emit DefaultRoyaltyUpdated(receiver, feeNumerator);
    }

    /**
     * @notice Set primary sale recipient
     * @param recipient The new primary sale recipient
     */
    function setPrimarySaleRecipient(address recipient) external onlyOwner {
        primarySaleRecipient = recipient;
    }

    /**
     * @notice Lazy mint tokens with URIs (increments nextTokenIdToLazyMint)
     * @param amount The number of tokens to lazy mint
     * @param baseURIs Array of URIs for the tokens
     */
    function lazyMint(uint256 amount, string[] calldata baseURIs) external override onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(baseURIs.length == amount, "URIs length must match amount");
        
        uint256 startTokenId = nextTokenIdToLazyMint;
        
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = startTokenId + i;
            require(bytes(_tokenURIs[tokenId]).length == 0, "Token URI already set");
            _tokenURIs[tokenId] = baseURIs[i];
            emit IDropErc1155.TokenURIUpdated(tokenId, baseURIs[i]);
        }
        
        nextTokenIdToLazyMint += amount;
        emit IDropErc1155.TokensLazyMinted(startTokenId, nextTokenIdToLazyMint - 1, baseURIs);
    }

    /**
     * @notice Get URI for a specific token
     * @param tokenId The token ID
     * @return The URI for the token metadata
     */
    function tokenURI(uint256 tokenId) external view override returns (string memory) {
        string memory _tokenURI = _tokenURIs[tokenId];
        
        // If no specific URI is set, return the base URI with token ID
        if (bytes(_tokenURI).length == 0) {
            return uri(tokenId);
        }
        
        return _tokenURI;
    }

    /**
     * @notice Owner mint function for airdrops or pre-minting
     * @param to The recipient address
     * @param tokenId The token ID
     * @param quantity The quantity to mint
     */
    function ownerMint(address to, uint256 tokenId, uint256 quantity) external onlyOwner {
        if (maxTotalSupply[tokenId] > 0) {
            if (totalSupply(tokenId) + quantity > maxTotalSupply[tokenId]) {
                revert DropExceedsMaxSupply();
            }
        }
        _mint(to, tokenId, quantity, "");
    }

    /**
     * @notice Batch owner mint function
     * @param to The recipient address
     * @param tokenIds Array of token IDs
     * @param quantities Array of quantities to mint
     */
    function ownerMintBatch(
        address to,
        uint256[] memory tokenIds,
        uint256[] memory quantities
    ) external onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (maxTotalSupply[tokenIds[i]] > 0) {
                if (totalSupply(tokenIds[i]) + quantities[i] > maxTotalSupply[tokenIds[i]]) {
                    revert DropExceedsMaxSupply();
                }
            }
        }
        _mintBatch(to, tokenIds, quantities, "");
    }

    /**
     * @notice Override required by Solidity for multiple inheritance
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) {
        super._update(from, to, ids, values);
    }

    /**
     * @notice Override required by Solidity for multiple inheritance
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, ERC2981, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Override totalSupply to resolve conflict between ERC1155Supply and IDropErc1155
     */
    function totalSupply(uint256 tokenId) public view override(ERC1155Supply, IDropErc1155) returns (uint256) {
        return super.totalSupply(tokenId);
    }

    /**
     * @notice Override uri to support per-token URIs
     * @param tokenId The token ID
     * @return The URI for the token metadata
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory _tokenURI = _tokenURIs[tokenId];
        
        // If no specific URI is set, return the base URI
        if (bytes(_tokenURI).length == 0) {
            return super.uri(tokenId);
        }
        
        return _tokenURI;
    }
} 