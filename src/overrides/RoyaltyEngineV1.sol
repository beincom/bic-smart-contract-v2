// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "../interfaces/IRoyaltyEngineV1.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

/**
 * @dev Royalty engine implementation
 */
contract RoyaltyEngineV1 is IRoyaltyEngineV1 {
    using ERC165Checker for address;

    // bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a
    bytes4 private constant IERC2981_INTERFACE_ID = 0x2a55205a;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IRoyaltyEngineV1).interfaceId || interfaceId == 0x01ffc9a7; // ERC165 interface ID
    }

    /**
     * @dev See {IRoyaltyEngineV1-getRoyalty}.
     */
    function getRoyalty(
        address tokenAddress,
        uint256 tokenId,
        uint256 value
    ) external view override returns (address payable[] memory recipients, uint256[] memory amounts) {
        return _getRoyalty(tokenAddress, tokenId, value);
    }

    /**
     * @dev See {IRoyaltyEngineV1-getRoyaltyView}.
     */
    function getRoyaltyView(
        address tokenAddress,
        uint256 tokenId,
        uint256 value
    ) external view override returns (address payable[] memory recipients, uint256[] memory amounts) {
        return _getRoyalty(tokenAddress, tokenId, value);
    }

    /**
     * @dev Internal implementation of getRoyalty
     */
    function _getRoyalty(
        address tokenAddress,
        uint256 tokenId,
        uint256 value
    ) internal view returns (address payable[] memory recipients, uint256[] memory amounts) {
        // Initialize empty arrays
        recipients = new address payable[](0);
        amounts = new uint256[](0);

        // Check for ERC2981 support
        if (tokenAddress.supportsInterface(IERC2981_INTERFACE_ID)) {
            try IERC2981(tokenAddress).royaltyInfo(tokenId, value) returns (address recipient, uint256 amount) {
                if (amount >= value) {
                    // Skip invalid royalty amounts in view function instead of reverting
                    return (recipients, amounts);
                }

                recipients = new address payable[](1);
                amounts = new uint256[](1);
                recipients[0] = payable(recipient);
                amounts[0] = amount;
            } catch {}
        }

        return (recipients, amounts);
    }
}
