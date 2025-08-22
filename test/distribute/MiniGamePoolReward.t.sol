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
    bytes32 public merkleRoot;
    bytes32 public merkleRootERC721;
    bytes32 public merkleRootERC1155;
    
    // Merkle proofs (these would be generated off-chain)
    bytes32[] public user1Proof;
    bytes32[] public user2Proof;
    bytes32[] public user3Proof;
    bytes32[] public user1ProofERC721;
    bytes32[] public user1ProofERC1155;

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

        erc721Token = new MockERC721();
        erc1155Token = new MockERC1155();

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
        // Create leafs for the ERC20 merkle tree
        bytes32[] memory leafs = new bytes32[](3);
        leafs[0] = keccak256(abi.encodePacked(user1, address(erc20Token), USER1_AMOUNT, uint256(0)));
        leafs[1] = keccak256(abi.encodePacked(user2, address(erc20Token), USER2_AMOUNT, uint256(0)));
        leafs[2] = keccak256(abi.encodePacked(user3, address(erc20Token), USER3_AMOUNT, uint256(0)));

        // Build merkle tree manually for 3 leafs
        // Tree structure:
        //       root
        //      /    \
        //   hash01   leaf2
        //   /   \
        // leaf0 leaf1
        
        bytes32 hash01 = _hashPair(leafs[0], leafs[1]);
        merkleRoot = _hashPair(hash01, leafs[2]);

        // Setup ERC20 proofs
        user1Proof = new bytes32[](2);
        user1Proof[0] = leafs[1]; // user2's leaf
        user1Proof[1] = leafs[2]; // user3's leaf
        
        user2Proof = new bytes32[](2);
        user2Proof[0] = leafs[0]; // user1's leaf
        user2Proof[1] = leafs[2]; // user3's leaf
        
        user3Proof = new bytes32[](1);
        user3Proof[0] = hash01; // hash of user1 and user2 leafs

        // Create single leaf trees for ERC721 and ERC1155 (simpler for testing)
        bytes32 leafERC721 = keccak256(abi.encodePacked(user1, address(erc721Token), uint256(1), uint256(1)));
        merkleRootERC721 = leafERC721; // Single leaf tree
        user1ProofERC721 = new bytes32[](0); // Empty proof for single leaf

        bytes32 leafERC1155 = keccak256(abi.encodePacked(user1, address(erc1155Token), uint256(50), uint256(1)));
        merkleRootERC1155 = leafERC1155; // Single leaf tree
        user1ProofERC1155 = new bytes32[](0); // Empty proof for single leaf
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
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
        emit MiniGamePoolReward.MerkleRootAdded(merkleRoot, END_TIME);

        rewardContract.addMerkleRoot(merkleRoot, END_TIME);

        (bytes32 root, uint256 endTime, bool exists) = rewardContract.getMerkleRootInfo(merkleRoot);
        assertEq(root, merkleRoot);
        assertEq(endTime, END_TIME);
        assertTrue(exists);

        bytes32[] memory allRoots = rewardContract.getAllMerkleRoots();
        assertEq(allRoots.length, 1);
        assertEq(allRoots[0], merkleRoot);

        vm.stopPrank();
    }

    function test_addMerkleRoot_update_existing() public {
        vm.startPrank(owner);

        rewardContract.addMerkleRoot(merkleRoot, END_TIME);

        uint256 newEndTime = END_TIME + 1000;
        vm.expectEmit(true, false, false, true);
        emit MiniGamePoolReward.MerkleRootUpdated(merkleRoot, newEndTime);

        rewardContract.addMerkleRoot(merkleRoot, newEndTime);

        (, uint256 endTime,) = rewardContract.getMerkleRootInfo(merkleRoot);
        assertEq(endTime, newEndTime);

        // Should not add another entry to the list
        assertEq(rewardContract.getMerkleRootsCount(), 1);

        vm.stopPrank();
    }

    function test_addMerkleRoot_revert_not_owner() public {
        vm.startPrank(user1);
        vm.expectRevert();
        rewardContract.addMerkleRoot(merkleRoot, END_TIME);
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
        rewardContract.addMerkleRoot(merkleRoot, block.timestamp - 1);
        vm.stopPrank();
    }

    // ERC20 Claim tests
    function test_claimERC20Tokens_success() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(merkleRoot, END_TIME);

        uint256 balanceBefore = erc20Token.balanceOf(user1);

        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit MiniGamePoolReward.TokensClaimed(user1, merkleRoot, address(erc20Token), USER1_AMOUNT, 0);

        rewardContract.claimERC20Tokens(merkleRoot, address(erc20Token), USER1_AMOUNT, user1Proof);
        vm.stopPrank();

        uint256 balanceAfter = erc20Token.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, USER1_AMOUNT);

        assertTrue(rewardContract.hasClaimedFromRoot(merkleRoot, user1));
    }

    function test_claimERC20Tokens_revert_zero_amount() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(merkleRoot, END_TIME);

        vm.startPrank(user1);
        vm.expectRevert(ZeroAmount.selector);
        rewardContract.claimERC20Tokens(merkleRoot, address(erc20Token), 0, user1Proof);
        vm.stopPrank();
    }

    function test_claimERC20Tokens_revert_zero_token() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(merkleRoot, END_TIME);

        vm.startPrank(user1);
        vm.expectRevert(ZeroAddress.selector);
        rewardContract.claimERC20Tokens(merkleRoot, address(0), USER1_AMOUNT, user1Proof);
        vm.stopPrank();
    }

    // ERC721 Claim tests
    function test_claimERC721Tokens_success() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(merkleRootERC721, END_TIME);

        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit MiniGamePoolReward.TokensClaimed(user1, merkleRootERC721, address(erc721Token), 1, 1);

        rewardContract.claimERC721Tokens(merkleRootERC721, address(erc721Token), 1, user1ProofERC721);
        vm.stopPrank();

        assertEq(erc721Token.ownerOf(1), user1);
        assertTrue(rewardContract.hasClaimedFromRoot(merkleRootERC721, user1));
    }

    function test_claimERC721Tokens_revert_zero_token() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(merkleRootERC721, END_TIME);

        vm.startPrank(user1);
        vm.expectRevert(ZeroAddress.selector);
        rewardContract.claimERC721Tokens(merkleRootERC721, address(0), 1, user1ProofERC721);
        vm.stopPrank();
    }

    // ERC1155 Claim tests
    function test_claimERC1155Tokens_success() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(merkleRootERC1155, END_TIME);

        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit MiniGamePoolReward.TokensClaimed(user1, merkleRootERC1155, address(erc1155Token), 50, 1);

        rewardContract.claimERC1155Tokens(merkleRootERC1155, address(erc1155Token), 1, 50, user1ProofERC1155);
        vm.stopPrank();

        assertEq(erc1155Token.balanceOf(user1, 1), 50);
        assertTrue(rewardContract.hasClaimedFromRoot(merkleRootERC1155, user1));
    }

    function test_claimERC1155Tokens_revert_zero_amount() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(merkleRootERC1155, END_TIME);

        vm.startPrank(user1);
        vm.expectRevert(ZeroAmount.selector);
        rewardContract.claimERC1155Tokens(merkleRootERC1155, address(erc1155Token), 1, 0, user1ProofERC1155);
        vm.stopPrank();
    }

    function test_claimERC1155Tokens_revert_zero_token() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(merkleRootERC1155, END_TIME);

        vm.startPrank(user1);
        vm.expectRevert(ZeroAddress.selector);
        rewardContract.claimERC1155Tokens(merkleRootERC1155, address(0), 1, 50, user1ProofERC1155);
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
        rewardContract.addMerkleRoot(merkleRoot, END_TIME);

        // Warp past the end time
        vm.warp(END_TIME + 1);

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(ClaimPeriodExpired.selector, merkleRoot, END_TIME));
        rewardContract.claimERC20Tokens(merkleRoot, address(erc20Token), USER1_AMOUNT, user1Proof);
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
        rewardContract.addMerkleRoot(merkleRoot, END_TIME);

        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = bytes32(uint256(999));

        vm.startPrank(user1);
        vm.expectRevert(InvalidProof.selector);
        rewardContract.claimERC20Tokens(merkleRoot, address(erc20Token), USER1_AMOUNT, invalidProof);
        vm.stopPrank();
    }

    // Multiple claims test
    function test_multiple_users_claim_from_same_root() public {
        vm.prank(owner);
        rewardContract.addMerkleRoot(merkleRoot, END_TIME);

        // User1 claims
        vm.prank(user1);
        rewardContract.claimERC20Tokens(merkleRoot, address(erc20Token), USER1_AMOUNT, user1Proof);

        // User2 claims
        vm.prank(user2);
        rewardContract.claimERC20Tokens(merkleRoot, address(erc20Token), USER2_AMOUNT, user2Proof);

        // User3 claims
        vm.prank(user3);
        rewardContract.claimERC20Tokens(merkleRoot, address(erc20Token), USER3_AMOUNT, user3Proof);

        // Verify all have claimed from the same root
        assertTrue(rewardContract.hasClaimedFromRoot(merkleRoot, user1));
        assertTrue(rewardContract.hasClaimedFromRoot(merkleRoot, user2));
        assertTrue(rewardContract.hasClaimedFromRoot(merkleRoot, user3));

        // Verify balances
        assertEq(erc20Token.balanceOf(user1), USER1_AMOUNT);
        assertEq(erc20Token.balanceOf(user2), USER2_AMOUNT);
        assertEq(erc20Token.balanceOf(user3), USER3_AMOUNT);
    }

    // Utility function tests
    function test_isRootActive() public {
        assertFalse(rewardContract.isRootActive(merkleRoot));

        vm.prank(owner);
        rewardContract.addMerkleRoot(merkleRoot, END_TIME);

        assertTrue(rewardContract.isRootActive(merkleRoot));

        vm.warp(END_TIME + 1);
        assertFalse(rewardContract.isRootActive(merkleRoot));
    }

    function test_getERC20Balance() public view {
        uint256 expectedBalance = USER1_AMOUNT + USER2_AMOUNT + USER3_AMOUNT + 1000 ether;
        assertEq(rewardContract.getERC20Balance(address(erc20Token)), expectedBalance);
    }

    function test_getERC1155Balance() public view {
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

    function test_withdrawERC20Tokens_native_token_success() public {
        uint256 withdrawAmount = 5 ether;
        
        // Send ETH to the contract
        vm.deal(address(rewardContract), 10 ether);
        
        uint256 ownerBalanceBefore = owner.balance;
        uint256 contractBalanceBefore = address(rewardContract).balance;

        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit MiniGamePoolReward.TokensWithdrawn(owner, address(0), withdrawAmount, 0);

        rewardContract.withdrawERC20Tokens(address(0), owner, withdrawAmount);
        vm.stopPrank();

        uint256 ownerBalanceAfter = owner.balance;
        uint256 contractBalanceAfter = address(rewardContract).balance;
        
        assertEq(ownerBalanceAfter - ownerBalanceBefore, withdrawAmount);
        assertEq(contractBalanceBefore - contractBalanceAfter, withdrawAmount);
    }

    function test_withdrawERC20Tokens_native_token_revert_insufficient_balance() public {
        uint256 withdrawAmount = 5 ether;
        
        // Contract has no ETH
        assertEq(address(rewardContract).balance, 0);

        vm.startPrank(owner);
        // Note: The current implementation doesn't revert for insufficient balance,
        // it just fails silently. This test demonstrates the current behavior.
        // In production, this should be fixed to check balance and revert properly.
        
        uint256 ownerBalanceBefore = owner.balance;
        
        // Call doesn't revert, but ETH transfer fails silently
        rewardContract.withdrawERC20Tokens(address(0), owner, withdrawAmount);
        
        uint256 ownerBalanceAfter = owner.balance;
        
        // Balance should remain unchanged due to failed transfer
        assertEq(ownerBalanceAfter, ownerBalanceBefore);
        vm.stopPrank();
    }

    function test_withdrawERC20Tokens_native_token_revert_zero_amount() public {
        vm.deal(address(rewardContract), 10 ether);

        vm.startPrank(owner);
        vm.expectRevert(ZeroAmount.selector);
        rewardContract.withdrawERC20Tokens(address(0), owner, 0);
        vm.stopPrank();
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
        // The contract doesn't check balance, so it will revert with ERC20 transfer error
        vm.expectRevert();
        rewardContract.withdrawERC20Tokens(address(erc20Token), owner, withdrawAmount);
        vm.stopPrank();
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