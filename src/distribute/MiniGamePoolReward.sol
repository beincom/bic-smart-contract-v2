// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MiniGamePoolRewardErrors} from "../interfaces/MiniGamePoolRewardErrors.sol";

/**
 * @title MiniGamePoolReward
 * @notice Contract for distributing ERC20 tokens using merkle trees with time-based claim periods
 * @dev Allows admin to add merkle roots with end times, users can claim rewards if they provide valid proofs
 */
contract MiniGamePoolReward is Ownable, ReentrancyGuard, MiniGamePoolRewardErrors {
    using SafeERC20 for IERC20;

    /// @notice The ERC20 token used for rewards
    IERC20 public immutable rewardToken;

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
        uint256 amount
    );

    /// @notice Emitted when tokens are withdrawn by admin
    event TokensWithdrawn(address indexed to, uint256 amount);

    /**
     * @notice Constructor to initialize the contract
     * @param _rewardToken The ERC20 token to be distributed as rewards
     * @param _owner The owner of the contract
     */
    constructor(IERC20 _rewardToken, address _owner) Ownable(_owner) {
        if (address(_rewardToken) == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();
        rewardToken = _rewardToken;
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
     * @notice Claim tokens using a merkle proof
     * @param _merkleRoot The merkle root to claim from
     * @param _amount The amount to claim
     * @param _merkleProof The merkle proof for the claim
     */
    function claimTokens(
        bytes32 _merkleRoot,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external nonReentrant {
        if (_amount == 0) revert ZeroAmount();

        MerkleRootInfo storage rootInfo = merkleRoots[_merkleRoot];
        if (!rootInfo.exists) revert RootNotFound(_merkleRoot);
        if (block.timestamp > rootInfo.endTime) revert ClaimPeriodExpired(_merkleRoot, rootInfo.endTime);
        if (hasClaimed[_merkleRoot][msg.sender]) revert AlreadyClaimed(msg.sender, _merkleRoot);

        // Verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _amount));
        if (!MerkleProof.verify(_merkleProof, _merkleRoot, leaf)) revert InvalidProof();

        // Check if contract has sufficient balance
        uint256 contractBalance = rewardToken.balanceOf(address(this));
        if (contractBalance < _amount) revert InsufficientBalance(_amount, contractBalance);

        // Mark as claimed
        hasClaimed[_merkleRoot][msg.sender] = true;

        // Transfer tokens
        rewardToken.safeTransfer(msg.sender, _amount);

        emit TokensClaimed(msg.sender, _merkleRoot, _amount);
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
     * @notice Get the contract's token balance
     * @return The current token balance of the contract
     */
    function getContractBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    /**
     * @notice Withdraw tokens from the contract (admin only)
     * @param _to The address to send tokens to
     * @param _amount The amount to withdraw
     */
    function withdrawTokens(address _to, uint256 _amount) external onlyOwner {
        if (_to == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();

        uint256 contractBalance = rewardToken.balanceOf(address(this));
        if (contractBalance < _amount) revert InsufficientBalance(_amount, contractBalance);

        rewardToken.safeTransfer(_to, _amount);
        emit TokensWithdrawn(_to, _amount);
    }

    /**
     * @notice Emergency withdraw all tokens (admin only)
     * @param _to The address to send tokens to
     */
    function emergencyWithdraw(address _to) external onlyOwner {
        if (_to == address(0)) revert ZeroAddress();

        uint256 balance = rewardToken.balanceOf(address(this));
        if (balance > 0) {
            rewardToken.safeTransfer(_to, balance);
            emit TokensWithdrawn(_to, balance);
        }
    }
}
