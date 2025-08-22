// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { LibDiamond } from "../../diamond/libraries/LibDiamond.sol";
import { LibAccess } from "../../diamond/libraries/LibAccess.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IDrop1155 } from "../../extension/interface/IDrop1155.sol";

contract MinigameExchangeFacet {
    using SafeERC20 for IERC20;

    /// @dev Token types for the MinigameRewardExchange event
    enum TokenType {
        Native,   // 0 - Native token (ETH/BNB etc.)
        ERC20,    // 1 - ERC20 token
        ERC721,   // 2 - ERC721 NFT
        ERC1155   // 3 - ERC1155 token
    }

    /// Events ///
    event MinigameRewardExchange(
        TokenType indexed tokenType,
        address indexed token,
        uint256 indexed tokenId,
        uint256 amount,
        address recipient,
        string message
    );

    /// Errors ///
    error InsufficientNativeBalance();
    error NativeTransferFailed();
    error InvalidTokenAddress();
    error InvalidRecipient();
    error InvalidAmount();
    error ClaimFailed();

    /// @notice Transfer native token (ETH/BNB) from contract to recipient
    /// @param _recipient The address to receive the native token
    /// @param _amount The amount of native token to transfer
    /// @param _message Custom message for the reward exchange
    function transferNative(
        address _recipient,
        uint256 _amount,
        string calldata _message
    ) external {
        LibAccess.enforceAccessControl();
        
        if (_recipient == address(0)) revert InvalidRecipient();
        if (_amount == 0) revert InvalidAmount();
        if (address(this).balance < _amount) revert InsufficientNativeBalance();

        (bool success, ) = _recipient.call{value: _amount}("");
        if (!success) revert NativeTransferFailed();

        emit MinigameRewardExchange(
            TokenType.Native,
            address(0), // Native token has no contract address
            0, // Native token has no tokenId
            _amount,
            _recipient,
            _message
        );
    }

    /// @notice Transfer ERC20 token from contract to recipient
    /// @param _token The ERC20 token contract address
    /// @param _recipient The address to receive the token
    /// @param _amount The amount of token to transfer
    /// @param _message Custom message for the reward exchange
    function transferERC20(
        address _token,
        address _recipient,
        uint256 _amount,
        string calldata _message
    ) external {
        LibAccess.enforceAccessControl();
        
        if (_token == address(0)) revert InvalidTokenAddress();
        if (_recipient == address(0)) revert InvalidRecipient();
        if (_amount == 0) revert InvalidAmount();

        IERC20(_token).safeTransfer(_recipient, _amount);

        emit MinigameRewardExchange(
            TokenType.ERC20,
            _token,
            0, // ERC20 has no tokenId
            _amount,
            _recipient,
            _message
        );
    }

    /// @notice Transfer ERC721 NFT from contract to recipient
    /// @param _token The ERC721 token contract address
    /// @param _recipient The address to receive the NFT
    /// @param _tokenId The token ID to transfer
    /// @param _message Custom message for the reward exchange
    function transferERC721(
        address _token,
        address _recipient,
        uint256 _tokenId,
        string calldata _message
    ) external {
        LibAccess.enforceAccessControl();
        
        if (_token == address(0)) revert InvalidTokenAddress();
        if (_recipient == address(0)) revert InvalidRecipient();

        IERC721(_token).safeTransferFrom(address(this), _recipient, _tokenId);

        emit MinigameRewardExchange(
            TokenType.ERC721,
            _token,
            _tokenId,
            1, // ERC721 amount is always 1
            _recipient,
            _message
        );
    }

    /// @notice Transfer ERC1155 token from contract to recipient
    /// @param _token The ERC1155 token contract address
    /// @param _recipient The address to receive the token
    /// @param _tokenId The token ID to transfer
    /// @param _amount The amount of token to transfer
    /// @param _message Custom message for the reward exchange
    function transferERC1155(
        address _token,
        address _recipient,
        uint256 _tokenId,
        uint256 _amount,
        string calldata _message
    ) external {
        LibAccess.enforceAccessControl();
        
        if (_token == address(0)) revert InvalidTokenAddress();
        if (_recipient == address(0)) revert InvalidRecipient();
        if (_amount == 0) revert InvalidAmount();

        IERC1155(_token).safeTransferFrom(
            address(this),
            _recipient,
            _tokenId,
            _amount,
            ""
        );

        emit MinigameRewardExchange(
            TokenType.ERC1155,
            _token,
            _tokenId,
            _amount,
            _recipient,
            _message
        );
    }

    /// @notice Batch transfer multiple ERC1155 tokens from contract to recipient
    /// @param _token The ERC1155 token contract address
    /// @param _recipient The address to receive the tokens
    /// @param _tokenIds Array of token IDs to transfer
    /// @param _amounts Array of amounts to transfer for each token ID
    /// @param _message Custom message for the reward exchange
    function transferERC1155Batch(
        address _token,
        address _recipient,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts,
        string calldata _message
    ) external {
        LibAccess.enforceAccessControl();
        
        if (_token == address(0)) revert InvalidTokenAddress();
        if (_recipient == address(0)) revert InvalidRecipient();
        if (_tokenIds.length != _amounts.length) revert InvalidAmount();
        if (_tokenIds.length == 0) revert InvalidAmount();

        IERC1155(_token).safeBatchTransferFrom(
            address(this),
            _recipient,
            _tokenIds,
            _amounts,
            ""
        );

        // Emit event for each token in the batch
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (_amounts[i] > 0) {
                emit MinigameRewardExchange(
                    TokenType.ERC1155,
                    _token,
                    _tokenIds[i],
                    _amounts[i],
                    _recipient,
                    _message
                );
            }
        }
    }

    /// @notice Claim ERC1155 tokens from a drop contract on behalf of a recipient
    /// @param _dropContract The IDrop1155 contract address to claim from
    /// @param _recipient The address to receive the claimed tokens
    /// @param _tokenId The token ID to claim
    /// @param _quantity The quantity of tokens to claim
    /// @param _currency The currency to pay for the claim
    /// @param _pricePerToken The price per token to pay
    /// @param _allowlistProof The allowlist proof for claiming
    /// @param _data Additional data for the claim
    /// @param _message Custom message for the reward exchange
    function claimERC1155(
        address _dropContract,
        address _recipient,
        uint256 _tokenId,
        uint256 _quantity,
        address _currency,
        uint256 _pricePerToken,
        IDrop1155.AllowlistProof calldata _allowlistProof,
        bytes memory _data,
        string calldata _message
    ) external payable {
        LibAccess.enforceAccessControl();
        
        if (_dropContract == address(0)) revert InvalidTokenAddress();
        if (_recipient == address(0)) revert InvalidRecipient();
        if (_quantity == 0) revert InvalidAmount();

        try IDrop1155(_dropContract).claim{value: msg.value}(
            _recipient,
            _tokenId,
            _quantity,
            _currency,
            _pricePerToken,
            _allowlistProof,
            _data
        ) {
            emit MinigameRewardExchange(
                TokenType.ERC1155,
                _dropContract,
                _tokenId,
                _quantity,
                _recipient,
                _message
            );
        } catch {
            revert ClaimFailed();
        }
    }

    /// @notice Check contract's native token balance
    /// @return balance The contract's native token balance
    function getNativeBalance() external view returns (uint256 balance) {
        return address(this).balance;
    }

    /// @notice Check contract's ERC20 token balance
    /// @param _token The ERC20 token contract address
    /// @return balance The contract's token balance
    function getERC20Balance(address _token) external view returns (uint256 balance) {
        return IERC20(_token).balanceOf(address(this));
    }

    /// @notice Check if contract owns a specific ERC721 token
    /// @param _token The ERC721 token contract address
    /// @param _tokenId The token ID to check
    /// @return owned True if the contract owns the token
    function ownsERC721(address _token, uint256 _tokenId) external view returns (bool owned) {
        return IERC721(_token).ownerOf(_tokenId) == address(this);
    }

    /// @notice Check contract's ERC1155 token balance
    /// @param _token The ERC1155 token contract address
    /// @param _tokenId The token ID to check
    /// @return balance The contract's token balance
    function getERC1155Balance(
        address _token,
        uint256 _tokenId
    ) external view returns (uint256 balance) {
        return IERC1155(_token).balanceOf(address(this), _tokenId);
    }
}
