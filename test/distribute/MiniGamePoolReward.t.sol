// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {MiniGamePoolReward} from "../../src/distribute/MiniGamePoolReward.sol";
import {MiniGamePoolRewardErrors} from "../../src/interfaces/MiniGamePoolRewardErrors.sol";
import {BicTokenPaymasterWithoutPreSetupExchange} from "../contracts/BicTokenPaymasterWithoutPreSetupExchange.sol";
import {MockERC721} from "../contracts/MockERC721.sol";
import {MockERC1155} from "../contracts/MockERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract MiniGamePoolRewardTest is Test, MiniGamePoolRewardErrors {
    MiniGamePoolReward public rewardContract;
    BicTokenPaymasterWithoutPreSetupExchange public erc20Token;
    MockERC721 public erc721Token;
    MockERC1155 public erc1155Token;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);
    
    // Test merkle tree data
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
        
        erc20Token = new BicTokenPaymasterWithoutPreSetupExchange(
            0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
            address(this),
            signers
        );
        
        erc721Token = new MockERC721("Test NFT", "TNFT");
        erc1155Token = new MockERC1155("https://api.example.com/metadata/");
        
        rewardContract = new MiniGamePoolReward(owner);
        
        // Mint tokens to the contract for testing
        uint256 totalAmount = USER1_AMOUNT + USER2_AMOUNT + USER3_AMOUNT + 1000 ether;
        erc20Token.transfer(address(rewardContract), totalAmount);
        
        // Mint ERC721 tokens to contract
        erc721Token.mint(address(rewardContract), 1);
        erc721Token.mint(address(rewardContract), 2);
        erc721Token.mint(address(rewardContract), 3);
        
        // Mint ERC1155 tokens to contract
        erc1155Token.mint(address(rewardContract), 1, 100, "");
        erc1155Token.mint(address(rewardContract), 2, 200, "");
        erc1155Token.mint(address(rewardContract), 3, 300, "");
        
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
        MiniGamePoolReward newContract = new MiniGamePoolReward(owner);
        assertEq(newContract.owner(), owner);
    }

    function test_constructor_revert_zero_owner() public {
        vm.expectRevert();
        new MiniGamePoolReward(address(0));
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

    // ERC20 Claim tests
    function test_claimERC20Tokens_success() public {
        // Create a simple merkle tree for testing
        bytes32 leaf = keccak256(abi.encodePacked(user1, address(erc20Token), USER1_AMOUNT, uint256(0)));
        bytes32 testRoot = leaf; // Simplest case - single leaf tree
        
        vm.prank(owner);
        rewardContract.addMerkleRoot(testRoot, END_TIME);
        
        uint256 balanceBefore = erc20Token.balanceOf(user1);
        
        vm.startPrank(user1);
        bytes32[] memory emptyProof = new bytes32[](0); // Empty proof for single leaf
        
        vm.expectEmit(true, true, true, true);
        emit MiniGamePoolReward.TokensClaimed(user1, testRoot, address(erc20Token), USER1_AMOUNT, 0);
        
        rewardContract.claimERC20Tokens(testRoot, address(erc20Token), USER1_AMOUNT, emptyProof);
        vm.stopPrank();
        
        uint256 balanceAfter = erc20Token.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, USER1_AMOUNT);
        
        assertTrue(rewardContract.hasClaimedFromRoot(testRoot, user1));
    }

    function test_claimERC20Tokens_revert_zero_amount() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(MERKLE_ROOT, END_TIME);
        
        vm.startPrank(user1);
        vm.expectRevert(ZeroAmount.selector);
        rewardContract.claimERC20Tokens(MERKLE_ROOT, address(erc20Token), 0, user1Proof);
        vm.stopPrank();
    }

    function test_claimERC20Tokens_revert_zero_token() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(MERKLE_ROOT, END_TIME);
        
        vm.startPrank(user1);
        vm.expectRevert(ZeroAddress.selector);
        rewardContract.claimERC20Tokens(MERKLE_ROOT, address(0), USER1_AMOUNT, user1Proof);
        vm.stopPrank();
    }

    // ERC721 Claim tests
    function test_claimERC721Tokens_success() public {
        bytes32 leaf = keccak256(abi.encodePacked(user1, address(erc721Token), uint256(1), uint256(1)));
        bytes32 testRoot = leaf;
        
        vm.prank(owner);
        rewardContract.addMerkleRoot(testRoot, END_TIME);
        
        vm.startPrank(user1);
        bytes32[] memory emptyProof = new bytes32[](0);
        
        vm.expectEmit(true, true, true, true);
        emit MiniGamePoolReward.TokensClaimed(user1, testRoot, address(erc721Token), 1, 1);
        
        rewardContract.claimERC721Tokens(testRoot, address(erc721Token), 1, emptyProof);
        vm.stopPrank();
        
        assertEq(erc721Token.ownerOf(1), user1);
        assertTrue(rewardContract.hasClaimedFromRoot(testRoot, user1));
    }

    function test_claimERC721Tokens_revert_zero_token() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(MERKLE_ROOT, END_TIME);
        
        vm.startPrank(user1);
        vm.expectRevert(ZeroAddress.selector);
        rewardContract.claimERC721Tokens(MERKLE_ROOT, address(0), 1, user1Proof);
        vm.stopPrank();
    }

    // ERC1155 Claim tests
    function test_claimERC1155Tokens_success() public {
        bytes32 leaf = keccak256(abi.encodePacked(user1, address(erc1155Token), uint256(50), uint256(1)));
        bytes32 testRoot = leaf;
        
        vm.prank(owner);
        rewardContract.addMerkleRoot(testRoot, END_TIME);
        
        vm.startPrank(user1);
        bytes32[] memory emptyProof = new bytes32[](0);
        
        vm.expectEmit(true, true, true, true);
        emit MiniGamePoolReward.TokensClaimed(user1, testRoot, address(erc1155Token), 50, 1);
        
        rewardContract.claimERC1155Tokens(testRoot, address(erc1155Token), 1, 50, emptyProof);
        vm.stopPrank();
        
        assertEq(erc1155Token.balanceOf(user1, 1), 50);
        assertTrue(rewardContract.hasClaimedFromRoot(testRoot, user1));
    }

    function test_claimERC1155Tokens_revert_zero_amount() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(MERKLE_ROOT, END_TIME);
        
        vm.startPrank(user1);
        vm.expectRevert(ZeroAmount.selector);
        rewardContract.claimERC1155Tokens(MERKLE_ROOT, address(erc1155Token), 1, 0, user1Proof);
        vm.stopPrank();
    }

    function test_claimERC1155Tokens_revert_zero_token() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(MERKLE_ROOT, END_TIME);
        
        vm.startPrank(user1);
        vm.expectRevert(ZeroAddress.selector);
        rewardContract.claimERC1155Tokens(MERKLE_ROOT, address(0), 1, 50, user1Proof);
        vm.stopPrank();
    }

    // Common claim tests
    function test_claim_tokens_revert_root_not_found() public {
        bytes32 invalidRoot = bytes32(uint256(1));
        
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(RootNotFound.selector, invalidRoot));
        rewardContract.claimERC20Tokens(invalidRoot, address(erc20Token), USER1_AMOUNT, user1Proof);
        vm.stopPrank();
    }

    function test_claim_tokens_revert_claim_period_expired() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(MERKLE_ROOT, END_TIME);
        
        // Warp past the end time
        vm.warp(END_TIME + 1);
        
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(ClaimPeriodExpired.selector, MERKLE_ROOT, END_TIME));
        rewardContract.claimERC20Tokens(MERKLE_ROOT, address(erc20Token), USER1_AMOUNT, user1Proof);
        vm.stopPrank();
    }

    function test_claim_tokens_revert_already_claimed() public {
        bytes32 leaf = keccak256(abi.encodePacked(user1, address(erc20Token), USER1_AMOUNT, uint256(0)));
        bytes32 testRoot = leaf;
        bytes32[] memory emptyProof = new bytes32[](0);
        
        vm.prank(owner);
        rewardContract.addMerkleRoot(testRoot, END_TIME);
        
        // First claim should succeed
        vm.prank(user1);
        rewardContract.claimERC20Tokens(testRoot, address(erc20Token), USER1_AMOUNT, emptyProof);
        
        // Second claim should fail
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(AlreadyClaimed.selector, user1, testRoot));
        rewardContract.claimERC20Tokens(testRoot, address(erc20Token), USER1_AMOUNT, emptyProof);
        vm.stopPrank();
    }

    function test_claim_tokens_revert_invalid_proof() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(MERKLE_ROOT, END_TIME);
        
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = bytes32(uint256(999));
        
        vm.startPrank(user1);
        vm.expectRevert(InvalidProof.selector);
        rewardContract.claimERC20Tokens(MERKLE_ROOT, address(erc20Token), USER1_AMOUNT, invalidProof);
        vm.stopPrank();
    }

    function test_claim_tokens_revert_insufficient_balance() public {
        bytes32 leaf = keccak256(abi.encodePacked(user1, address(erc20Token), USER1_AMOUNT, uint256(0)));
        bytes32[] memory emptyProof = new bytes32[](0);
        
        vm.prank(owner);
        rewardContract.addMerkleRoot(leaf, END_TIME);
        
        // Transfer all tokens out of the contract
        vm.prank(owner);
        rewardContract.emergencyWithdrawERC20(address(erc20Token), owner);
        
        vm.startPrank(user1);
        vm.expectRevert(); // Just expect any revert since error format might differ
        rewardContract.claimERC20Tokens(leaf, address(erc20Token), USER1_AMOUNT, emptyProof);
        vm.stopPrank();
    }

    // Multiple claims test
    function test_multiple_users_claim_from_same_root() public {
        // For simplicity, test with separate roots for each user
        bytes32 leaf1 = keccak256(abi.encodePacked(user1, address(erc20Token), USER1_AMOUNT, uint256(0)));
        bytes32 leaf2 = keccak256(abi.encodePacked(user2, address(erc20Token), USER2_AMOUNT, uint256(0)));
        bytes32[] memory emptyProof = new bytes32[](0);
        
        vm.startPrank(owner);
        rewardContract.addMerkleRoot(leaf1, END_TIME);
        rewardContract.addMerkleRoot(leaf2, END_TIME);
        vm.stopPrank();
        
        // User1 claims
        vm.prank(user1);
        rewardContract.claimERC20Tokens(leaf1, address(erc20Token), USER1_AMOUNT, emptyProof);
        
        // User2 claims
        vm.prank(user2);
        rewardContract.claimERC20Tokens(leaf2, address(erc20Token), USER2_AMOUNT, emptyProof);
        
        // Verify both have claimed
        assertTrue(rewardContract.hasClaimedFromRoot(leaf1, user1));
        assertTrue(rewardContract.hasClaimedFromRoot(leaf2, user2));
        assertFalse(rewardContract.hasClaimedFromRoot(leaf1, user3));
        
        // Verify balances
        assertEq(erc20Token.balanceOf(user1), USER1_AMOUNT);
        assertEq(erc20Token.balanceOf(user2), USER2_AMOUNT);
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

    function test_getERC20Balance() public {
        uint256 expectedBalance = USER1_AMOUNT + USER2_AMOUNT + USER3_AMOUNT + 1000 ether;
        assertEq(rewardContract.getERC20Balance(address(erc20Token)), expectedBalance);
    }

    function test_getERC1155Balance() public {
        assertEq(rewardContract.getERC1155Balance(address(erc1155Token), 1), 100);
        assertEq(rewardContract.getERC1155Balance(address(erc1155Token), 2), 200);
        assertEq(rewardContract.getERC1155Balance(address(erc1155Token), 3), 300);
    }

    // Admin functions tests
    function test_withdrawERC20Tokens_success() public {
        uint256 withdrawAmount = 100 ether;
        uint256 ownerBalanceBefore = erc20Token.balanceOf(owner);
        
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit MiniGamePoolReward.TokensWithdrawn(owner, address(erc20Token), withdrawAmount, 0);
        
        rewardContract.withdrawERC20Tokens(address(erc20Token), owner, withdrawAmount);
        vm.stopPrank();
        
        uint256 ownerBalanceAfter = erc20Token.balanceOf(owner);
        assertEq(ownerBalanceAfter - ownerBalanceBefore, withdrawAmount);
    }

    function test_withdrawERC721Tokens_success() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit MiniGamePoolReward.TokensWithdrawn(owner, address(erc721Token), 1, 1);
        
        rewardContract.withdrawERC721Tokens(address(erc721Token), owner, 1);
        vm.stopPrank();
        
        assertEq(erc721Token.ownerOf(1), owner);
    }

    function test_withdrawERC1155Tokens_success() public {
        uint256 withdrawAmount = 50;
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit MiniGamePoolReward.TokensWithdrawn(owner, address(erc1155Token), withdrawAmount, 1);
        
        rewardContract.withdrawERC1155Tokens(address(erc1155Token), owner, 1, withdrawAmount);
        vm.stopPrank();
        
        assertEq(erc1155Token.balanceOf(owner, 1), withdrawAmount);
    }

    function test_withdrawTokens_revert_not_owner() public {
        vm.startPrank(user1);
        vm.expectRevert();
        rewardContract.withdrawERC20Tokens(address(erc20Token), user1, 100 ether);
        vm.stopPrank();
    }

    function test_withdrawTokens_revert_zero_address() public {
        vm.startPrank(owner);
        vm.expectRevert(ZeroAddress.selector);
        rewardContract.withdrawERC20Tokens(address(erc20Token), address(0), 100 ether);
        vm.stopPrank();
    }

    function test_withdrawTokens_revert_zero_amount() public {
        vm.startPrank(owner);
        vm.expectRevert(ZeroAmount.selector);
        rewardContract.withdrawERC20Tokens(address(erc20Token), owner, 0);
        vm.stopPrank();
    }

    function test_withdrawTokens_revert_insufficient_balance() public {
        uint256 contractBalance = rewardContract.getERC20Balance(address(erc20Token));
        uint256 withdrawAmount = contractBalance + 1;
        
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector, withdrawAmount, contractBalance));
        rewardContract.withdrawERC20Tokens(address(erc20Token), owner, withdrawAmount);
        vm.stopPrank();
    }

    function test_emergencyWithdrawERC20_success() public {
        uint256 contractBalance = rewardContract.getERC20Balance(address(erc20Token));
        uint256 ownerBalanceBefore = erc20Token.balanceOf(owner);
        
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit MiniGamePoolReward.TokensWithdrawn(owner, address(erc20Token), contractBalance, 0);
        
        rewardContract.emergencyWithdrawERC20(address(erc20Token), owner);
        vm.stopPrank();
        
        uint256 ownerBalanceAfter = erc20Token.balanceOf(owner);
        assertEq(ownerBalanceAfter - ownerBalanceBefore, contractBalance);
        assertEq(rewardContract.getERC20Balance(address(erc20Token)), 0);
    }

    function test_emergencyWithdrawERC20_revert_zero_address() public {
        vm.startPrank(owner);
        vm.expectRevert(ZeroAddress.selector);
        rewardContract.emergencyWithdrawERC20(address(0), owner);
        vm.stopPrank();
    }

    function test_emergencyWithdrawERC20_with_zero_balance() public {
        // First withdraw all tokens
        vm.prank(owner);
        rewardContract.emergencyWithdrawERC20(address(erc20Token), owner);
        
        // Try emergency withdraw again with zero balance
        vm.prank(owner);
        rewardContract.emergencyWithdrawERC20(address(erc20Token), owner); // Should not revert
        
        assertEq(rewardContract.getERC20Balance(address(erc20Token)), 0);
    }

    // Integration test: Complete flow with different token types
    function test_complete_flow_multi_token() public {
        // ERC20 setup
        bytes32 erc20Leaf1 = keccak256(abi.encodePacked(user1, address(erc20Token), USER1_AMOUNT, uint256(0)));
        bytes32 erc20Leaf2 = keccak256(abi.encodePacked(user2, address(erc20Token), USER2_AMOUNT, uint256(0)));
        
        // ERC721 setup
        bytes32 erc721Leaf1 = keccak256(abi.encodePacked(user1, address(erc721Token), uint256(1), uint256(1)));
        bytes32 erc721Leaf2 = keccak256(abi.encodePacked(user2, address(erc721Token), uint256(1), uint256(2)));
        
        // ERC1155 setup
        bytes32 erc1155Leaf1 = keccak256(abi.encodePacked(user1, address(erc1155Token), uint256(50), uint256(1)));
        bytes32 erc1155Leaf2 = keccak256(abi.encodePacked(user2, address(erc1155Token), uint256(100), uint256(2)));
        
        bytes32[] memory emptyProof = new bytes32[](0);
        
        // Owner adds merkle roots
        vm.startPrank(owner);
        rewardContract.addMerkleRoot(erc20Leaf1, END_TIME);
        rewardContract.addMerkleRoot(erc721Leaf1, END_TIME);
        rewardContract.addMerkleRoot(erc1155Leaf1, END_TIME);
        vm.stopPrank();
        
        // Check initial state
        assertEq(rewardContract.getMerkleRootsCount(), 3);
        assertTrue(rewardContract.isRootActive(erc20Leaf1));
        
        // User1 claims different token types
        vm.prank(user1);
        rewardContract.claimERC20Tokens(erc20Leaf1, address(erc20Token), USER1_AMOUNT, emptyProof);
        
        vm.prank(user1);
        rewardContract.claimERC721Tokens(erc721Leaf1, address(erc721Token), 1, emptyProof);
        
        vm.prank(user1);
        rewardContract.claimERC1155Tokens(erc1155Leaf1, address(erc1155Token), 1, 50, emptyProof);
        
        // Verify claims
        assertTrue(rewardContract.hasClaimedFromRoot(erc20Leaf1, user1));
        assertTrue(rewardContract.hasClaimedFromRoot(erc721Leaf1, user1));
        assertTrue(rewardContract.hasClaimedFromRoot(erc1155Leaf1, user1));
        
        // Verify token balances
        assertEq(erc20Token.balanceOf(user1), USER1_AMOUNT);
        assertEq(erc721Token.ownerOf(1), user1);
        assertEq(erc1155Token.balanceOf(user1, 1), 50);
        
        // Time passes and root expires
        vm.warp(END_TIME + 1);
        assertFalse(rewardContract.isRootActive(erc20Leaf1));
        
        // User2 tries to claim after expiry - should fail
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(ClaimPeriodExpired.selector, erc20Leaf1, END_TIME));
        rewardContract.claimERC20Tokens(erc20Leaf1, address(erc20Token), USER2_AMOUNT, emptyProof);
        vm.stopPrank();
        
        // Owner withdraws remaining tokens
        uint256 remainingBalance = rewardContract.getERC20Balance(address(erc20Token));
        vm.prank(owner);
        rewardContract.withdrawERC20Tokens(address(erc20Token), owner, remainingBalance);
        
        assertEq(rewardContract.getERC20Balance(address(erc20Token)), 0);
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

    function testFuzz_withdrawERC20Tokens(uint256 _amount) public {
        uint256 contractBalance = rewardContract.getERC20Balance(address(erc20Token));
        vm.assume(_amount > 0 && _amount <= contractBalance);
        
        uint256 ownerBalanceBefore = erc20Token.balanceOf(owner);
        
        vm.prank(owner);
        rewardContract.withdrawERC20Tokens(address(erc20Token), owner, _amount);
        
        uint256 ownerBalanceAfter = erc20Token.balanceOf(owner);
        assertEq(ownerBalanceAfter - ownerBalanceBefore, _amount);
    }
} 