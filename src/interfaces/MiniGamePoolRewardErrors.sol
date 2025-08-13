// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

interface MiniGamePoolRewardErrors {
    error InvalidMerkleRoot();
    error InvalidEndTime(uint256 endTime);
    error AlreadyClaimed(address claimer, bytes32 merkleRoot);
    error InvalidProof();
    error ClaimPeriodExpired(bytes32 merkleRoot, uint256 endTime);
    error ClaimPeriodNotStarted(bytes32 merkleRoot);
    error InsufficientBalance(uint256 required, uint256 available);
    error ZeroAmount();
    error ZeroAddress();
    error RootNotFound(bytes32 merkleRoot);
} 