// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author thirdweb
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { TokenBundle, ITokenBundle } from "./TokenBundle.sol";

contract TokenStore is TokenBundle, ERC721Holder, ERC1155Holder {
    using SafeERC20 for IERC20;

    /// @dev Store / escrow multiple ERC1155, ERC721, ERC20 tokens.
    function _storeTokens(
        address _tokenOwner,
        Token[] calldata _tokens,
        string memory _uriForTokens,
        uint256 _idForTokens
    ) internal {
        _createBundle(_tokens, _idForTokens);
        _setUriOfBundle(_uriForTokens, _idForTokens);
        _transferTokenBatch(_tokenOwner, address(this), _tokens);
    }

    /// @dev Release stored / escrowed ERC1155, ERC721, ERC20 tokens.
    function _releaseTokens(address _recipient, uint256 _idForContent) internal {
        uint256 count = getTokenCountOfBundle(_idForContent);
        Token[] memory tokensToRelease = new Token[](count);

        for (uint256 i = 0; i < count; i += 1) {
            tokensToRelease[i] = getTokenOfBundle(_idForContent, i);
        }

        _deleteBundle(_idForContent);

        _transferTokenBatch(address(this), _recipient, tokensToRelease);
    }

    /// @dev Transfers an arbitrary ERC20 / ERC721 / ERC1155 token.
    function _transferToken(address _from, address _to, Token memory _token) internal {
        if (_token.tokenType == TokenType.ERC20) {
            if(_from == address(this)) {
                IERC20(_token.assetContract).transfer(_to, _token.totalAmount);
            } else {
                IERC20(_token.assetContract).safeTransferFrom(_from, _to, _token.totalAmount);
            }
        } else if (_token.tokenType == TokenType.ERC721) {
            IERC721(_token.assetContract).safeTransferFrom(_from, _to, _token.tokenId);
        } else if (_token.tokenType == TokenType.ERC1155) {
            IERC1155(_token.assetContract).safeTransferFrom(_from, _to, _token.tokenId, _token.totalAmount, "");
        }
    }

    /// @dev Transfers multiple arbitrary ERC20 / ERC721 / ERC1155 tokens.
    function _transferTokenBatch(address _from, address _to, Token[] memory _tokens) internal {
        uint256 nativeTokenValue;
        for (uint256 i = 0; i < _tokens.length; i += 1) {
            _transferToken(_from, _to, _tokens[i]);
        }
    }
}