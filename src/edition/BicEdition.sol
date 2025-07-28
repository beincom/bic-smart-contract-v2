// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {LazyMint} from "../extension/LazyMint.sol";
import {Drop1155} from "../extension/Drop1155.sol";

contract BicEdition is ERC1155Supply, Ownable, LazyMint, Drop1155 {
    using SafeERC20 for IERC20;

    // Token name
    string public name;

    // Token symbol
    string public symbol;

    /// @notice Mapping from token ID to max total supply
    mapping(uint256 => uint256) public maxTotalSupply;
    
    /// @notice Primary sale recipient for primary sales
    address public primarySaleRecipient;

    event PrimarySaleRecipientSet(address recipient);
    event MaxTotalSupplySet(uint256 tokenId, uint256 maxTotalSupply);

    error DropExceedsMaxSupply();
    error DropInvalidPrice();
    error DropTransferFailed();

    constructor(
        string memory name_,
        string memory symbol_,
        string memory uri_,
        address owner_,
        address primarySaleRecipient_
    ) ERC1155(uri_) Ownable(owner_) {
        name = name_;
        symbol = symbol_;
        primarySaleRecipient = primarySaleRecipient_;    
    }

    /**
     * @notice Set primary sale recipient
     * @param recipient The new primary sale recipient
     */
    function setPrimarySaleRecipient(address recipient) external onlyOwner {
        primarySaleRecipient = recipient;
        emit PrimarySaleRecipientSet(recipient);
    }

    /**
     * @notice Set max total supply for a token
     * @param _tokenId The token ID
     * @param _maxTotalSupply The new max total supply
     */
    function setMaxTotalSupply(uint256 _tokenId, uint256 _maxTotalSupply) external onlyOwner {
        maxTotalSupply[_tokenId] = _maxTotalSupply;
        emit MaxTotalSupplySet(_tokenId, _maxTotalSupply);
    }

    function baseURI() public view returns (string memory) {
        return super.uri(0); // Return the base URI for the contract
    }

    /**
     * @notice Get URI for a specific token
     * @param tokenId The token ID
     * @return The URI for the token metadata
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        string memory _tokenURI = _getBaseURI(tokenId);

        // If no specific URI is set, return the base URI with token ID
        if (bytes(_tokenURI).length == 0) {
            return uri(tokenId);
        }

        return _tokenURI;
    }

    /**
     * @notice Override uri to support per-token URIs
     * @param tokenId The token ID
     * @return The URI for the token metadata
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory _tokenURI = _getBaseURI(tokenId);

        // If no specific URI is set, return the base URI
        if (bytes(_tokenURI).length == 0) {
            return string(abi.encodePacked(baseURI(), Strings.toString(tokenId)));
        }

        return _tokenURI;
    }

    function _beforeClaim(
        uint256 _tokenId,
        address,
        uint256 _quantity,
        address,
        uint256,
        AllowlistProof calldata,
        bytes memory
    ) internal view override {
        // Verify supply limits
        if (maxTotalSupply[_tokenId] > 0) {
            if (totalSupply(_tokenId) + _quantity > maxTotalSupply[_tokenId]) {
                revert DropExceedsMaxSupply();
            }
        }
    }

    /// @dev Collects and distributes the primary sale value of NFTs being claimed.
    function collectPriceOnClaim(
        uint256 /* _tokenId */,
        address /* _primarySaleRecipient */,
        uint256 _quantityToClaim,
        address _currency,
        uint256 _pricePerToken
    ) internal override {
        if (_pricePerToken == 0) {
            revert DropClaimInvalidTokenPrice(_currency, _pricePerToken, address(0), 0);
        }
        uint256 totalPrice = _quantityToClaim * _pricePerToken;

        if (_currency == address(0)) {
            // ETH payment
            if (msg.value != totalPrice) revert DropInvalidPrice();
            if (totalPrice > 0) {
                (bool success,) = payable(primarySaleRecipient).call{value: totalPrice}("");
                if (!success) revert DropTransferFailed();
            }
        } else {
            // ERC20 payment
            if (msg.value != 0) revert DropInvalidPrice();
            if (totalPrice > 0) {
                IERC20(_currency).safeTransferFrom(msg.sender, primarySaleRecipient, totalPrice);
            }
        }
    }

    /// @dev Transfers the NFTs being claimed.
    function transferTokensOnClaim(address _to, uint256 _tokenId, uint256 _quantityBeingClaimed) internal override {
        _mint(_to, _tokenId, _quantityBeingClaimed, "");
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

    function _canLazyMint() internal view virtual override returns (bool) {
        return msg.sender == owner();
    }

    function _canSetClaimConditions() internal view virtual override returns (bool) {
        return msg.sender == owner();
    }

    function _dropMsgSender() internal view virtual override returns (address) {
        return msg.sender;
    }
}