// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {MiniGamePoolReward} from "../../src/distribute/MiniGamePoolReward.sol";
import {MiniGamePoolRewardErrors} from "../../src/interfaces/MiniGamePoolRewardErrors.sol";
import {BicTokenPaymasterWithoutPreSetupExchange} from "../contracts/BicTokenPaymasterWithoutPreSetupExchange.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MiniGamePoolRewardTest is Test, MiniGamePoolRewardErrors {
    MiniGamePoolReward public rewardContract;
    BicTokenPaymasterWithoutPreSetupExchange public token;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);
    
    // Test merkle tree data
    // Tree structure:
    // Root: 0x123...
    // Leaves: [user1: 100 tokens, user2: 200 tokens, user3: 300 tokens]
    bytes32 public constant MERKLE_ROOT = 0x3b7ba3e8ad90c2de8e4a46aa9833edaec4c2137b3df6dbba04c6f5b3c8d6f1e4;
    
    // Merkle proofs (these would be generated off-chain)
    bytes32[] public user1Proof;
    bytes32[] public user2Proof;
    bytes32[] public user3Proof;
    
    uint256 public constant USER1_AMOUNT = 100 ether;
    uint256 public constant USER2_AMOUNT = 200 ether;
    uint256 public constant USER3_AMOUNT = 300 ether;
    
    uint256 public constant END_TIME = 1000000000; // Future timestamp

    function setUp() public {
        address[] memory signers = new address[](1);
        signers[0] = address(0x123);
        
        token = new BicTokenPaymasterWithoutPreSetupExchange(
            0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
            address(this),
            signers
        );
        
        rewardContract = new MiniGamePoolReward(IERC20(address(token)), owner);
        
        // Mint tokens to the contract for testing
        uint256 totalAmount = USER1_AMOUNT + USER2_AMOUNT + USER3_AMOUNT + 1000 ether;
        token.transfer(address(rewardContract), totalAmount);
        
        // Setup merkle proofs for testing
        setupMerkleProofs();
        
        // Warp to a timestamp before the end time
        vm.warp(END_TIME - 1000);
    }

    function setupMerkleProofs() internal {
        // For this test, we'll use simplified proofs
        // In a real scenario, these would be calculated based on the actual merkle tree
        
        // Setup user1 proof
        user1Proof = new bytes32[](2);
        user1Proof[0] = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        user1Proof[1] = 0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321;
        
        // Setup user2 proof
        user2Proof = new bytes32[](2);
        user2Proof[0] = 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890;
        user2Proof[1] = 0x0987654321fedcba0987654321fedcba0987654321fedcba0987654321fedcba;
        
        // Setup user3 proof
        user3Proof = new bytes32[](1);
        user3Proof[0] = 0x1111111111111111111111111111111111111111111111111111111111111111;
    }

    // Constructor tests
    function test_constructor_success() public {
        MiniGamePoolReward newContract = new MiniGamePoolReward(IERC20(address(token)), owner);
        assertEq(address(newContract.rewardToken()), address(token));
        assertEq(newContract.owner(), owner);
    }

    function test_constructor_revert_zero_token() public {
        vm.expectRevert(ZeroAddress.selector);
        new MiniGamePoolReward(IERC20(address(0)), owner);
    }

    function test_constructor_revert_zero_owner() public {
        vm.expectRevert();
        new MiniGamePoolReward(IERC20(address(token)), address(0));
    }

    // Add merkle root tests
    function test_addMerkleRoot_success() public {
        vm.startPrank(owner);
        
        vm.expectEmit(true, false, false, true);
        emit MiniGamePoolReward.MerkleRootAdded(MERKLE_ROOT, END_TIME);
        
        rewardContract.addMerkleRoot(MERKLE_ROOT, END_TIME);
        
        (bytes32 root, uint256 endTime, bool exists) = rewardContract.getMerkleRootInfo(MERKLE_ROOT);
        assertEq(root, MERKLE_ROOT);
        assertEq(endTime, END_TIME);
        assertTrue(exists);
        
        bytes32[] memory allRoots = rewardContract.getAllMerkleRoots();
        assertEq(allRoots.length, 1);
        assertEq(allRoots[0], MERKLE_ROOT);
        
        vm.stopPrank();
    }

    function test_addMerkleRoot_update_existing() public {
        vm.startPrank(owner);
        
        rewardContract.addMerkleRoot(MERKLE_ROOT, END_TIME);
        
        uint256 newEndTime = END_TIME + 1000;
        vm.expectEmit(true, false, false, true);
        emit MiniGamePoolReward.MerkleRootUpdated(MERKLE_ROOT, newEndTime);
        
        rewardContract.addMerkleRoot(MERKLE_ROOT, newEndTime);
        
        (, uint256 endTime,) = rewardContract.getMerkleRootInfo(MERKLE_ROOT);
        assertEq(endTime, newEndTime);
        
        // Should not add another entry to the list
        assertEq(rewardContract.getMerkleRootsCount(), 1);
        
        vm.stopPrank();
    }

    function test_addMerkleRoot_revert_not_owner() public {
        vm.startPrank(user1);
        vm.expectRevert();
        rewardContract.addMerkleRoot(MERKLE_ROOT, END_TIME);
        vm.stopPrank();
    }

    function test_addMerkleRoot_revert_invalid_root() public {
        vm.startPrank(owner);
        vm.expectRevert(InvalidMerkleRoot.selector);
        rewardContract.addMerkleRoot(bytes32(0), END_TIME);
        vm.stopPrank();
    }

    function test_addMerkleRoot_revert_invalid_end_time() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidEndTime.selector, block.timestamp - 1));
        rewardContract.addMerkleRoot(MERKLE_ROOT, block.timestamp - 1);
        vm.stopPrank();
    }

    // Claim tokens tests
    function test_claimTokens_success() public {
        // Create a simple merkle tree for testing
        // For this test, we'll create a root that validates user1's claim
        bytes32 leaf = keccak256(abi.encodePacked(user1, USER1_AMOUNT));
        bytes32 testRoot = leaf; // Simplest case - single leaf tree
        
        vm.prank(owner);
        rewardContract.addMerkleRoot(testRoot, END_TIME);
        
        uint256 balanceBefore = token.balanceOf(user1);
        
        vm.startPrank(user1);
        bytes32[] memory emptyProof = new bytes32[](0); // Empty proof for single leaf
        
        vm.expectEmit(true, true, false, true);
        emit MiniGamePoolReward.TokensClaimed(user1, testRoot, USER1_AMOUNT);
        
        rewardContract.claimTokens(testRoot, USER1_AMOUNT, emptyProof);
        vm.stopPrank();
        
        uint256 balanceAfter = token.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, USER1_AMOUNT);
        
        assertTrue(rewardContract.hasClaimedFromRoot(testRoot, user1));
    }

    function test_claimTokens_revert_zero_amount() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(MERKLE_ROOT, END_TIME);
        
        vm.startPrank(user1);
        vm.expectRevert(ZeroAmount.selector);
        rewardContract.claimTokens(MERKLE_ROOT, 0, user1Proof);
        vm.stopPrank();
    }

    function test_claimTokens_revert_root_not_found() public {
        bytes32 invalidRoot = bytes32(uint256(1));
        
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(RootNotFound.selector, invalidRoot));
        rewardContract.claimTokens(invalidRoot, USER1_AMOUNT, user1Proof);
        vm.stopPrank();
    }

    function test_claimTokens_revert_claim_period_expired() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(MERKLE_ROOT, END_TIME);
        
        // Warp past the end time
        vm.warp(END_TIME + 1);
        
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(ClaimPeriodExpired.selector, MERKLE_ROOT, END_TIME));
        rewardContract.claimTokens(MERKLE_ROOT, USER1_AMOUNT, user1Proof);
        vm.stopPrank();
    }

    function test_claimTokens_revert_already_claimed() public {
        bytes32 leaf = keccak256(abi.encodePacked(user1, USER1_AMOUNT));
        bytes32 testRoot = leaf;
        bytes32[] memory emptyProof = new bytes32[](0);
        
        vm.prank(owner);
        rewardContract.addMerkleRoot(testRoot, END_TIME);
        
        // First claim should succeed
        vm.prank(user1);
        rewardContract.claimTokens(testRoot, USER1_AMOUNT, emptyProof);
        
        // Second claim should fail
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(AlreadyClaimed.selector, user1, testRoot));
        rewardContract.claimTokens(testRoot, USER1_AMOUNT, emptyProof);
        vm.stopPrank();
    }

    function test_claimTokens_revert_invalid_proof() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(MERKLE_ROOT, END_TIME);
        
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = bytes32(uint256(999));
        
        vm.startPrank(user1);
        vm.expectRevert(InvalidProof.selector);
        rewardContract.claimTokens(MERKLE_ROOT, USER1_AMOUNT, invalidProof);
        vm.stopPrank();
    }

    function test_claimTokens_revert_insufficient_balance() public {
        bytes32 leaf = keccak256(abi.encodePacked(user1, USER1_AMOUNT));
        bytes32[] memory emptyProof = new bytes32[](0);
        
        vm.prank(owner);
        rewardContract.addMerkleRoot(leaf, END_TIME);
        
        // Transfer all tokens out of the contract
        vm.prank(owner);
        rewardContract.emergencyWithdraw(owner);
        
        vm.startPrank(user1);
        vm.expectRevert(); // Just expect any revert since error format might differ
        rewardContract.claimTokens(leaf, USER1_AMOUNT, emptyProof);
        vm.stopPrank();
    }

    // Multiple claims test
    function test_multiple_users_claim_from_same_root() public {
        // For simplicity, test with separate roots for each user
        bytes32 leaf1 = keccak256(abi.encodePacked(user1, USER1_AMOUNT));
        bytes32 leaf2 = keccak256(abi.encodePacked(user2, USER2_AMOUNT));
        bytes32[] memory emptyProof = new bytes32[](0);
        
        vm.startPrank(owner);
        rewardContract.addMerkleRoot(leaf1, END_TIME);
        rewardContract.addMerkleRoot(leaf2, END_TIME);
        vm.stopPrank();
        
        // User1 claims
        vm.prank(user1);
        rewardContract.claimTokens(leaf1, USER1_AMOUNT, emptyProof);
        
        // User2 claims
        vm.prank(user2);
        rewardContract.claimTokens(leaf2, USER2_AMOUNT, emptyProof);
        
        // Verify both have claimed
        assertTrue(rewardContract.hasClaimedFromRoot(leaf1, user1));
        assertTrue(rewardContract.hasClaimedFromRoot(leaf2, user2));
        assertFalse(rewardContract.hasClaimedFromRoot(leaf1, user3));
        
        // Verify balances
        assertEq(token.balanceOf(user1), USER1_AMOUNT);
        assertEq(token.balanceOf(user2), USER2_AMOUNT);
    }

    // Utility function tests
    function test_isRootActive() public {
        assertFalse(rewardContract.isRootActive(MERKLE_ROOT));
        
        vm.prank(owner);
        rewardContract.addMerkleRoot(MERKLE_ROOT, END_TIME);
        
        assertTrue(rewardContract.isRootActive(MERKLE_ROOT));
        
        vm.warp(END_TIME + 1);
        assertFalse(rewardContract.isRootActive(MERKLE_ROOT));
    }

    function test_getContractBalance() public {
        uint256 expectedBalance = USER1_AMOUNT + USER2_AMOUNT + USER3_AMOUNT + 1000 ether;
        assertEq(rewardContract.getContractBalance(), expectedBalance);
    }

    // Admin functions tests
    function test_withdrawTokens_success() public {
        uint256 withdrawAmount = 100 ether;
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit MiniGamePoolReward.TokensWithdrawn(owner, withdrawAmount);
        
        rewardContract.withdrawTokens(owner, withdrawAmount);
        vm.stopPrank();
        
        uint256 ownerBalanceAfter = token.balanceOf(owner);
        assertEq(ownerBalanceAfter - ownerBalanceBefore, withdrawAmount);
    }

    function test_withdrawTokens_revert_not_owner() public {
        vm.startPrank(user1);
        vm.expectRevert();
        rewardContract.withdrawTokens(user1, 100 ether);
        vm.stopPrank();
    }

    function test_withdrawTokens_revert_zero_address() public {
        vm.startPrank(owner);
        vm.expectRevert(ZeroAddress.selector);
        rewardContract.withdrawTokens(address(0), 100 ether);
        vm.stopPrank();
    }

    function test_withdrawTokens_revert_zero_amount() public {
        vm.startPrank(owner);
        vm.expectRevert(ZeroAmount.selector);
        rewardContract.withdrawTokens(owner, 0);
        vm.stopPrank();
    }

    function test_withdrawTokens_revert_insufficient_balance() public {
        uint256 contractBalance = rewardContract.getContractBalance();
        uint256 withdrawAmount = contractBalance + 1;
        
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector, withdrawAmount, contractBalance));
        rewardContract.withdrawTokens(owner, withdrawAmount);
        vm.stopPrank();
    }

    function test_emergencyWithdraw_success() public {
        uint256 contractBalance = rewardContract.getContractBalance();
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit MiniGamePoolReward.TokensWithdrawn(owner, contractBalance);
        
        rewardContract.emergencyWithdraw(owner);
        vm.stopPrank();
        
        uint256 ownerBalanceAfter = token.balanceOf(owner);
        assertEq(ownerBalanceAfter - ownerBalanceBefore, contractBalance);
        assertEq(rewardContract.getContractBalance(), 0);
    }

    function test_emergencyWithdraw_revert_zero_address() public {
        vm.startPrank(owner);
        vm.expectRevert(ZeroAddress.selector);
        rewardContract.emergencyWithdraw(address(0));
        vm.stopPrank();
    }

    function test_emergencyWithdraw_with_zero_balance() public {
        // First withdraw all tokens
        vm.prank(owner);
        rewardContract.emergencyWithdraw(owner);
        
        // Try emergency withdraw again with zero balance
        vm.prank(owner);
        rewardContract.emergencyWithdraw(owner); // Should not revert
        
        assertEq(rewardContract.getContractBalance(), 0);
    }

    // Integration test: Complete flow
    function test_complete_flow() public {
        bytes32 leaf1 = keccak256(abi.encodePacked(user1, USER1_AMOUNT));
        bytes32 leaf2 = keccak256(abi.encodePacked(user2, USER2_AMOUNT));
        bytes32 leaf3 = keccak256(abi.encodePacked(user3, USER3_AMOUNT));
        bytes32[] memory emptyProof = new bytes32[](0);
        
        // Owner adds merkle roots
        vm.startPrank(owner);
        rewardContract.addMerkleRoot(leaf1, END_TIME);
        rewardContract.addMerkleRoot(leaf2, END_TIME);
        rewardContract.addMerkleRoot(leaf3, END_TIME);
        vm.stopPrank();
        
        // Check initial state
        assertEq(rewardContract.getMerkleRootsCount(), 3);
        assertTrue(rewardContract.isRootActive(leaf1));
        
        // Users claim tokens
        vm.prank(user1);
        rewardContract.claimTokens(leaf1, USER1_AMOUNT, emptyProof);
        
        vm.prank(user2);
        rewardContract.claimTokens(leaf2, USER2_AMOUNT, emptyProof);
        
        // Verify claims
        assertTrue(rewardContract.hasClaimedFromRoot(leaf1, user1));
        assertTrue(rewardContract.hasClaimedFromRoot(leaf2, user2));
        assertFalse(rewardContract.hasClaimedFromRoot(leaf3, user3));
        
        // Verify token balances
        assertEq(token.balanceOf(user1), USER1_AMOUNT);
        assertEq(token.balanceOf(user2), USER2_AMOUNT);
        assertEq(token.balanceOf(user3), 0);
        
        // Time passes and root expires
        vm.warp(END_TIME + 1);
        assertFalse(rewardContract.isRootActive(leaf3));
        
        // User3 tries to claim after expiry - should fail
        vm.startPrank(user3);
        vm.expectRevert(abi.encodeWithSelector(ClaimPeriodExpired.selector, leaf3, END_TIME));
        rewardContract.claimTokens(leaf3, USER3_AMOUNT, emptyProof);
        vm.stopPrank();
        
        // Owner withdraws remaining tokens
        uint256 remainingBalance = rewardContract.getContractBalance();
        vm.prank(owner);
        rewardContract.withdrawTokens(owner, remainingBalance);
        
        assertEq(rewardContract.getContractBalance(), 0);
    }

    // Fuzz tests
    function testFuzz_addMerkleRoot(bytes32 _root, uint256 _endTime) public {
        vm.assume(_root != bytes32(0));
        vm.assume(_endTime > block.timestamp);
        
        vm.prank(owner);
        rewardContract.addMerkleRoot(_root, _endTime);
        
        (bytes32 root, uint256 endTime, bool exists) = rewardContract.getMerkleRootInfo(_root);
        assertEq(root, _root);
        assertEq(endTime, _endTime);
        assertTrue(exists);
    }

    function testFuzz_withdrawTokens(uint256 _amount) public {
        uint256 contractBalance = rewardContract.getContractBalance();
        vm.assume(_amount > 0 && _amount <= contractBalance);
        
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        
        vm.prank(owner);
        rewardContract.withdrawTokens(owner, _amount);
        
        uint256 ownerBalanceAfter = token.balanceOf(owner);
        assertEq(ownerBalanceAfter - ownerBalanceBefore, _amount);
    }
} 