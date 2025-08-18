// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MiniGamePoolRewardErrors} from "../interfaces/MiniGamePoolRewardErrors.sol";

/**
 * @title MiniGamePoolReward
 * @notice Contract for distributing ERC20, ERC721, and ERC1155 tokens using merkle trees with time-based claim periods
 * @dev Allows admin to add merkle roots with end times, users can claim rewards if they provide valid proofs
 */
contract MiniGamePoolReward is Ownable, ReentrancyGuard, IERC721Receiver, IERC1155Receiver, MiniGamePoolRewardErrors {
    using SafeERC20 for IERC20;

    /// @notice Structure to store merkle root information
    struct MerkleRootInfo {
        bytes32 root;
        uint256 endTime;
        bool exists;
    }

    /// @notice Mapping from merkle root to its information
    mapping(bytes32 => MerkleRootInfo) public merkleRoots;

    /// @notice Mapping to track if an address has claimed from a specific merkle root
    /// @dev merkleRoot => claimer => hasClaimed
    mapping(bytes32 => mapping(address => bool)) public hasClaimed;

    /// @notice Array to keep track of all merkle roots for enumeration
    bytes32[] public merkleRootsList;

    /// @notice Emitted when a new merkle root is added
    event MerkleRootAdded(bytes32 indexed root, uint256 endTime);

    /// @notice Emitted when a merkle root is updated
    event MerkleRootUpdated(bytes32 indexed root, uint256 newEndTime);

    /// @notice Emitted when tokens are claimed
    event TokensClaimed(
        address indexed claimer,
        bytes32 indexed merkleRoot,
        address indexed token,
        uint256 amount,
        uint256 tokenId
    );

    /// @notice Emitted when tokens are withdrawn by admin
    event TokensWithdrawn(address indexed to, address indexed token, uint256 amount, uint256 tokenId);

    /**
     * @notice Constructor to initialize the contract
     * @param _owner The owner of the contract
     */
    constructor(address _owner) Ownable(_owner) {
        if (_owner == address(0)) revert ZeroAddress();
    }

    /**
     * @notice Add a new merkle root with an end time for claims
     * @param _merkleRoot The merkle root to add
     * @param _endTime The timestamp when claims for this root expire
     */
    function addMerkleRoot(bytes32 _merkleRoot, uint256 _endTime) external onlyOwner {
        if (_merkleRoot == bytes32(0)) revert InvalidMerkleRoot();
        if (_endTime <= block.timestamp) revert InvalidEndTime(_endTime);

        // If root already exists, update it
        if (merkleRoots[_merkleRoot].exists) {
            merkleRoots[_merkleRoot].endTime = _endTime;
            emit MerkleRootUpdated(_merkleRoot, _endTime);
        } else {
            merkleRoots[_merkleRoot] = MerkleRootInfo({
                root: _merkleRoot,
                endTime: _endTime,
                exists: true
            });
            merkleRootsList.push(_merkleRoot);
            emit MerkleRootAdded(_merkleRoot, _endTime);
        }
    }

    /**
     * @notice Claim ERC20 tokens using a merkle proof
     * @param _merkleRoot The merkle root to claim from
     * @param _token The ERC20 token address
     * @param _amount The amount to claim
     * @param _merkleProof The merkle proof for the claim
     */
    function claimERC20Tokens(
        bytes32 _merkleRoot,
        address _token,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external nonReentrant {
        if (_amount == 0) revert ZeroAmount();
        if (_token == address(0)) revert ZeroAddress();

        MerkleRootInfo storage rootInfo = merkleRoots[_merkleRoot];
        if (!rootInfo.exists) revert RootNotFound(_merkleRoot);
        if (block.timestamp > rootInfo.endTime) revert ClaimPeriodExpired(_merkleRoot, rootInfo.endTime);
        if (hasClaimed[_merkleRoot][msg.sender]) revert AlreadyClaimed(msg.sender, _merkleRoot);

        // Verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _token, _amount, uint256(0))); // tokenId = 0 for ERC20
        if (!MerkleProof.verify(_merkleProof, _merkleRoot, leaf)) revert InvalidProof();

        // Check if contract has sufficient balance
        uint256 contractBalance = IERC20(_token).balanceOf(address(this));
        if (contractBalance < _amount) revert InsufficientBalance(_amount, contractBalance);

        // Mark as claimed
        hasClaimed[_merkleRoot][msg.sender] = true;

        // Transfer tokens
        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit TokensClaimed(msg.sender, _merkleRoot, _token, _amount, 0);
    }

    /**
     * @notice Claim ERC721 tokens using a merkle proof
     * @param _merkleRoot The merkle root to claim from
     * @param _token The ERC721 token address
     * @param _tokenId The token ID to claim
     * @param _merkleProof The merkle proof for the claim
     */
    function claimERC721Tokens(
        bytes32 _merkleRoot,
        address _token,
        uint256 _tokenId,
        bytes32[] calldata _merkleProof
    ) external nonReentrant {
        if (_token == address(0)) revert ZeroAddress();

        MerkleRootInfo storage rootInfo = merkleRoots[_merkleRoot];
        if (!rootInfo.exists) revert RootNotFound(_merkleRoot);
        if (block.timestamp > rootInfo.endTime) revert ClaimPeriodExpired(_merkleRoot, rootInfo.endTime);
        if (hasClaimed[_merkleRoot][msg.sender]) revert AlreadyClaimed(msg.sender, _merkleRoot);

        // Verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _token, uint256(1), _tokenId)); // amount = 1 for ERC721
        if (!MerkleProof.verify(_merkleProof, _merkleRoot, leaf)) revert InvalidProof();

        // Check if contract owns the token
        if (IERC721(_token).ownerOf(_tokenId) != address(this)) revert InsufficientBalance(1, 0);

        // Mark as claimed
        hasClaimed[_merkleRoot][msg.sender] = true;

        // Transfer token
        IERC721(_token).transferFrom(address(this), msg.sender, _tokenId);

        emit TokensClaimed(msg.sender, _merkleRoot, _token, 1, _tokenId);
    }

    /**
     * @notice Claim ERC1155 tokens using a merkle proof
     * @param _merkleRoot The merkle root to claim from
     * @param _token The ERC1155 token address
     * @param _tokenId The token ID to claim
     * @param _amount The amount to claim
     * @param _merkleProof The merkle proof for the claim
     */
    function claimERC1155Tokens(
        bytes32 _merkleRoot,
        address _token,
        uint256 _tokenId,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external nonReentrant {
        if (_amount == 0) revert ZeroAmount();
        if (_token == address(0)) revert ZeroAddress();

        MerkleRootInfo storage rootInfo = merkleRoots[_merkleRoot];
        if (!rootInfo.exists) revert RootNotFound(_merkleRoot);
        if (block.timestamp > rootInfo.endTime) revert ClaimPeriodExpired(_merkleRoot, rootInfo.endTime);
        if (hasClaimed[_merkleRoot][msg.sender]) revert AlreadyClaimed(msg.sender, _merkleRoot);

        // Verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _token, _amount, _tokenId));
        if (!MerkleProof.verify(_merkleProof, _merkleRoot, leaf)) revert InvalidProof();

        // Check if contract has sufficient balance
        uint256 contractBalance = IERC1155(_token).balanceOf(address(this), _tokenId);
        if (contractBalance < _amount) revert InsufficientBalance(_amount, contractBalance);

        // Mark as claimed
        hasClaimed[_merkleRoot][msg.sender] = true;

        // Transfer tokens
        IERC1155(_token).safeTransferFrom(address(this), msg.sender, _tokenId, _amount, "");

        emit TokensClaimed(msg.sender, _merkleRoot, _token, _amount, _tokenId);
    }

    /**
     * @notice Check if an address has claimed from a specific merkle root
     * @param _merkleRoot The merkle root to check
     * @param _claimer The address to check
     * @return True if the address has claimed, false otherwise
     */
    function hasClaimedFromRoot(bytes32 _merkleRoot, address _claimer) external view returns (bool) {
        return hasClaimed[_merkleRoot][_claimer];
    }

    /**
     * @notice Get information about a merkle root
     * @param _merkleRoot The merkle root to query
     * @return root The merkle root
     * @return endTime The end time for claims
     * @return exists Whether the root exists
     */
    function getMerkleRootInfo(bytes32 _merkleRoot) external view returns (bytes32 root, uint256 endTime, bool exists) {
        MerkleRootInfo storage info = merkleRoots[_merkleRoot];
        return (info.root, info.endTime, info.exists);
    }

    /**
     * @notice Get all merkle roots
     * @return Array of all merkle roots
     */
    function getAllMerkleRoots() external view returns (bytes32[] memory) {
        return merkleRootsList;
    }

    /**
     * @notice Get the number of merkle roots
     * @return The count of merkle roots
     */
    function getMerkleRootsCount() external view returns (uint256) {
        return merkleRootsList.length;
    }

    /**
     * @notice Check if a merkle root is active (exists and not expired)
     * @param _merkleRoot The merkle root to check
     * @return True if active, false otherwise
     */
    function isRootActive(bytes32 _merkleRoot) external view returns (bool) {
        MerkleRootInfo storage info = merkleRoots[_merkleRoot];
        return info.exists && block.timestamp <= info.endTime;
    }

    /**
     * @notice Get the contract's ERC20 token balance
     * @param _token The ERC20 token address
     * @return The current token balance of the contract
     */
    function getERC20Balance(address _token) external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    /**
     * @notice Get the contract's ERC1155 token balance
     * @param _token The ERC1155 token address
     * @param _tokenId The token ID
     * @return The current token balance of the contract
     */
    function getERC1155Balance(address _token, uint256 _tokenId) external view returns (uint256) {
        return IERC1155(_token).balanceOf(address(this), _tokenId);
    }

    /**
     * @notice Withdraw ERC20 tokens from the contract (admin only)
     * @param _token The ERC20 token address
     * @param _to The address to send tokens to
     * @param _amount The amount to withdraw
     */
    function withdrawERC20Tokens(address _token, address _to, uint256 _amount) external onlyOwner {
        if (_to == address(0)) revert ZeroAddress();
        if (_token == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();

        uint256 contractBalance = IERC20(_token).balanceOf(address(this));
        if (contractBalance < _amount) revert InsufficientBalance(_amount, contractBalance);

        IERC20(_token).safeTransfer(_to, _amount);
        emit TokensWithdrawn(_to, _token, _amount, 0);
    }

    /**
     * @notice Withdraw ERC721 tokens from the contract (admin only)
     * @param _token The ERC721 token address
     * @param _to The address to send tokens to
     * @param _tokenId The token ID to withdraw
     */
    function withdrawERC721Tokens(address _token, address _to, uint256 _tokenId) external onlyOwner {
        if (_to == address(0)) revert ZeroAddress();
        if (_token == address(0)) revert ZeroAddress();

        if (IERC721(_token).ownerOf(_tokenId) != address(this)) revert InsufficientBalance(1, 0);

        IERC721(_token).transferFrom(address(this), _to, _tokenId);
        emit TokensWithdrawn(_to, _token, 1, _tokenId);
    }

    /**
     * @notice Withdraw ERC1155 tokens from the contract (admin only)
     * @param _token The ERC1155 token address
     * @param _to The address to send tokens to
     * @param _tokenId The token ID to withdraw
     * @param _amount The amount to withdraw
     */
    function withdrawERC1155Tokens(address _token, address _to, uint256 _tokenId, uint256 _amount) external onlyOwner {
        if (_to == address(0)) revert ZeroAddress();
        if (_token == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();

        uint256 contractBalance = IERC1155(_token).balanceOf(address(this), _tokenId);
        if (contractBalance < _amount) revert InsufficientBalance(_amount, contractBalance);

        IERC1155(_token).safeTransferFrom(address(this), _to, _tokenId, _amount, "");
        emit TokensWithdrawn(_to, _token, _amount, _tokenId);
    }

    /**
     * @notice Emergency withdraw all ERC20 tokens (admin only)
     * @param _token The ERC20 token address
     * @param _to The address to send tokens to
     */
    function emergencyWithdrawERC20(address _token, address _to) external onlyOwner {
        if (_to == address(0)) revert ZeroAddress();
        if (_token == address(0)) revert ZeroAddress();

        uint256 balance = IERC20(_token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(_token).safeTransfer(_to, balance);
            emit TokensWithdrawn(_to, _token, balance, 0);
        }
    }

    /**
     * @notice ERC721Receiver interface implementation
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @notice ERC1155Receiver interface implementation
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    /**
     * @notice ERC1155Receiver interface implementation for batch transfers
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    /**
     * @notice IERC165 interface implementation
     */
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return 
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId;
    }
}
