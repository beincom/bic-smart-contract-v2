// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title MiniGamePointShop
 * @notice Contract for claiming ETH, ERC20, ERC721, and ERC1155 tokens after verification
 * @dev Users submit requests that must be signed by a verifier address to claim tokens
 */
contract MiniGamePointShop is Ownable, ReentrancyGuard, IERC721Receiver, IERC1155Receiver {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    /// @notice Structure for token claim requests
    struct ClaimRequest {
        address user;
        address token;
        uint256 amount;
        uint256 tokenId;
        uint256 nonce;
        uint256 deadline;
        TokenType tokenType;
    }

    /// @notice Enum for different token types
    enum TokenType {
        ETH,
        ERC20,
        ERC721,
        ERC1155
    }

    /// @notice Address of the verifier that signs claim requests
    address public verifier;

    /// @notice Mapping to track used nonces to prevent replay attacks
    mapping(uint256 => bool) public usedNonces;

    /// @notice Mapping to track total claims per user per token
    mapping(address => mapping(address => uint256)) public userTokenClaims;

    /// @notice Emitted when the verifier is updated
    event VerifierUpdated(address indexed oldVerifier, address indexed newVerifier);

    /// @notice Emitted when tokens are claimed
    event TokensClaimed(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 tokenId,
        TokenType tokenType,
        uint256 nonce
    );

    /// @notice Emitted when tokens are withdrawn by admin
    event TokensWithdrawn(
        address indexed to,
        address indexed token,
        uint256 amount,
        uint256 tokenId,
        TokenType tokenType
    );

    /// @notice Custom errors
    error ZeroAddress();
    error InvalidVerifier();
    error InvalidSignature();
    error InvalidNonce();
    error ExpiredDeadline();
    error InvalidTokenType();
    error InsufficientBalance();
    error TransferFailed();
    error InvalidAmount();
    error InvalidTokenId();

    /**
     * @notice Constructor to initialize the contract
     * @param _owner The owner of the contract
     * @param _verifier The address of the verifier
     */
    constructor(address _owner, address _verifier) Ownable(_owner) {
        if (_owner == address(0)) revert ZeroAddress();
        if (_verifier == address(0)) revert InvalidVerifier();
        verifier = _verifier;
    }

    /**
     * @notice Update the verifier address
     * @param _newVerifier The new verifier address
     */
    function updateVerifier(address _newVerifier) external onlyOwner {
        if (_newVerifier == address(0)) revert InvalidVerifier();
        address oldVerifier = verifier;
        verifier = _newVerifier;
        emit VerifierUpdated(oldVerifier, _newVerifier);
    }

    /**
     * @notice Claim ETH tokens
     * @param _request The claim request structure
     * @param _signature The signature from the verifier
     */
    function claimETH(ClaimRequest calldata _request, bytes calldata _signature) 
        external 
        nonReentrant 
    {
        if (_request.tokenType != TokenType.ETH) revert InvalidTokenType();
        if (_request.amount == 0) revert InvalidAmount();
        
        _validateAndProcessClaim(_request, _signature);
        
        // Transfer ETH to user
        (bool success, ) = _request.user.call{value: _request.amount}("");
        if (!success) revert TransferFailed();

        emit TokensClaimed(
            _request.user,
            address(0),
            _request.amount,
            0,
            TokenType.ETH,
            _request.nonce
        );
    }

    /**
     * @notice Claim ERC20 tokens
     * @param _request The claim request structure
     * @param _signature The signature from the verifier
     */
    function claimERC20(ClaimRequest calldata _request, bytes calldata _signature) 
        external 
        nonReentrant 
    {
        if (_request.tokenType != TokenType.ERC20) revert InvalidTokenType();
        if (_request.amount == 0) revert InvalidAmount();
        
        _validateAndProcessClaim(_request, _signature);
        
        // Transfer ERC20 tokens to user
        IERC20 token = IERC20(_request.token);
        if (token.balanceOf(address(this)) < _request.amount) revert InsufficientBalance();
        
        token.safeTransfer(_request.user, _request.amount);

        emit TokensClaimed(
            _request.user,
            _request.token,
            _request.amount,
            0,
            TokenType.ERC20,
            _request.nonce
        );
    }

    /**
     * @notice Claim ERC721 tokens
     * @param _request The claim request structure
     * @param _signature The signature from the verifier
     */
    function claimERC721(ClaimRequest calldata _request, bytes calldata _signature) 
        external 
        nonReentrant 
    {
        if (_request.tokenType != TokenType.ERC721) revert InvalidTokenType();
        if (_request.tokenId == 0) revert InvalidTokenId();
        
        _validateAndProcessClaim(_request, _signature);
        
        // Transfer ERC721 token to user
        IERC721 token = IERC721(_request.token);
        if (token.ownerOf(_request.tokenId) != address(this)) revert InsufficientBalance();
        
        token.safeTransferFrom(address(this), _request.user, _request.tokenId);

        emit TokensClaimed(
            _request.user,
            _request.token,
            1,
            _request.tokenId,
            TokenType.ERC721,
            _request.nonce
        );
    }

    /**
     * @notice Claim ERC1155 tokens
     * @param _request The claim request structure
     * @param _signature The signature from the verifier
     */
    function claimERC1155(ClaimRequest calldata _request, bytes calldata _signature) 
        external 
        nonReentrant 
    {
        if (_request.tokenType != TokenType.ERC1155) revert InvalidTokenType();
        if (_request.amount == 0) revert InvalidAmount();
        if (_request.tokenId == 0) revert InvalidTokenId();
        
        _validateAndProcessClaim(_request, _signature);
        
        // Transfer ERC1155 tokens to user
        IERC1155 token = IERC1155(_request.token);
        if (token.balanceOf(address(this), _request.tokenId) < _request.amount) revert InsufficientBalance();
        
        token.safeTransferFrom(address(this), _request.user, _request.tokenId, _request.amount, "");

        emit TokensClaimed(
            _request.user,
            _request.token,
            _request.amount,
            _request.tokenId,
            TokenType.ERC1155,
            _request.nonce
        );
    }

    /**
     * @notice Withdraw ETH from contract (admin only)
     * @param _to The address to send ETH to
     * @param _amount The amount to withdraw
     */
    function withdrawETH(address _to, uint256 _amount) external onlyOwner {
        if (_to == address(0)) revert ZeroAddress();
        if (_amount == 0) revert InvalidAmount();
        if (address(this).balance < _amount) revert InsufficientBalance();
        
        (bool success, ) = _to.call{value: _amount}("");
        if (!success) revert TransferFailed();
        
        emit TokensWithdrawn(_to, address(0), _amount, 0, TokenType.ETH);
    }

    /**
     * @notice Withdraw ERC20 tokens from contract (admin only)
     * @param _token The ERC20 token address
     * @param _to The address to send tokens to
     * @param _amount The amount to withdraw
     */
    function withdrawERC20(address _token, address _to, uint256 _amount) external onlyOwner {
        if (_token == address(0) || _to == address(0)) revert ZeroAddress();
        if (_amount == 0) revert InvalidAmount();
        
        IERC20 token = IERC20(_token);
        if (token.balanceOf(address(this)) < _amount) revert InsufficientBalance();
        
        token.safeTransfer(_to, _amount);
        
        emit TokensWithdrawn(_to, _token, _amount, 0, TokenType.ERC20);
    }

    /**
     * @notice Withdraw ERC721 tokens from contract (admin only)
     * @param _token The ERC721 token address
     * @param _to The address to send tokens to
     * @param _tokenId The token ID to withdraw
     */
    function withdrawERC721(address _token, address _to, uint256 _tokenId) external onlyOwner {
        if (_token == address(0) || _to == address(0)) revert ZeroAddress();
        if (_tokenId == 0) revert InvalidTokenId();
        
        IERC721 token = IERC721(_token);
        if (token.ownerOf(_tokenId) != address(this)) revert InsufficientBalance();
        
        token.safeTransferFrom(address(this), _to, _tokenId);
        
        emit TokensWithdrawn(_to, _token, 1, _tokenId, TokenType.ERC721);
    }

    /**
     * @notice Withdraw ERC1155 tokens from contract (admin only)
     * @param _token The ERC1155 token address
     * @param _to The address to send tokens to
     * @param _tokenId The token ID to withdraw
     * @param _amount The amount to withdraw
     */
    function withdrawERC1155(
        address _token, 
        address _to, 
        uint256 _tokenId, 
        uint256 _amount
    ) external onlyOwner {
        if (_token == address(0) || _to == address(0)) revert ZeroAddress();
        if (_amount == 0) revert InvalidAmount();
        if (_tokenId == 0) revert InvalidTokenId();
        
        IERC1155 token = IERC1155(_token);
        if (token.balanceOf(address(this), _tokenId) < _amount) revert InsufficientBalance();
        
        token.safeTransferFrom(address(this), _to, _tokenId, _amount, "");
        
        emit TokensWithdrawn(_to, _token, _amount, _tokenId, TokenType.ERC1155);
    }

    /**
     * @notice Get the hash of a claim request
     * @param _request The claim request
     * @return The hash of the request
     */
    function getClaimRequestHash(ClaimRequest calldata _request) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            _request.user,
            _request.token,
            _request.amount,
            _request.tokenId,
            _request.nonce,
            _request.deadline,
            _request.tokenType
        ));
    }

    /**
     * @notice Internal function to validate and process a claim
     * @param _request The claim request
     * @param _signature The signature from the verifier
     */
    function _validateAndProcessClaim(ClaimRequest calldata _request, bytes calldata _signature) internal {
        // Check if nonce has been used
        if (usedNonces[_request.nonce]) revert InvalidNonce();
        
        // Check if deadline has passed
        if (block.timestamp > _request.deadline) revert ExpiredDeadline();
        
        // Verify signature
        bytes32 messageHash = getClaimRequestHash(_request);
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        address signer = ethSignedMessageHash.recover(_signature);
        
        if (signer != verifier) revert InvalidSignature();
        
        // Mark nonce as used
        usedNonces[_request.nonce] = true;
        
        // Update user claims
        userTokenClaims[_request.user][_request.token] += _request.amount;
    }

    /**
     * @notice Required by IERC721Receiver
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * @notice Required by IERC1155Receiver
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @notice Required by IERC1155Receiver
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @notice Check if contract supports an interface
     */
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId ||
               interfaceId == type(IERC1155Receiver).interfaceId;
    }

    /**
     * @notice Receive ETH
     */
    receive() external payable {}
}
