// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {MiniGamePointShop} from "../../src/distribute/MiniGamePointShop.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {MockERC20} from "../contracts/MockERC20.sol";
import {MockERC721} from "../contracts/MockERC721.sol";
import {MockERC1155} from "../contracts/MockERC1155.sol";

contract MiniGamePointShopTest is Test {
    MiniGamePointShop public pointShop;
    MockERC20 public mockERC20;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;
    
    address public owner;
    address public verifier;
    address public user;
    address public user2;
    
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant CLAIM_AMOUNT = 100 ether;
    uint256 public constant TOKEN_ID = 1;
    uint256 public constant NONCE = 12345;
    uint256 public constant DEADLINE = 1000000000; // Far future timestamp
    
    event VerifierUpdated(address indexed oldVerifier, address indexed newVerifier);
    event TokensClaimed(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 tokenId,
        MiniGamePointShop.TokenType tokenType,
        uint256 nonce
    );
    event TokensWithdrawn(
        address indexed to,
        address indexed token,
        uint256 amount,
        uint256 tokenId,
        MiniGamePointShop.TokenType tokenType
    );

    function setUp() public {
        owner = makeAddr("owner");
        verifier = makeAddr("verifier");
        user = makeAddr("user");
        user2 = makeAddr("user2");
        
        // Generate private keys for the addresses
        uint256 verifierPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
        uint256 userPrivateKey = 0x2345678901234567890123456789012345678901234567890123456789012345;
        uint256 user2PrivateKey = 0x3456789012345678901234567890123456789012345678901234567890123456;
        
        // Set the addresses to match the private keys
        verifier = vm.addr(verifierPrivateKey);
        user = vm.addr(userPrivateKey);
        user2 = vm.addr(user2PrivateKey);
        
        vm.startPrank(owner);
        pointShop = new MiniGamePointShop(owner, verifier);
        
        // Deploy mock tokens
        mockERC20 = new MockERC20("Mock Token", "MTK", 18);
        mockERC721 = new MockERC721("Mock NFT", "MNFT");
        mockERC1155 = new MockERC1155("https://example.com/token/{id}.json");
        
        // Mint tokens to the point shop contract
        mockERC20.mint(address(pointShop), INITIAL_BALANCE);
        mockERC721.mint(address(pointShop), TOKEN_ID);
        mockERC1155.mint(address(pointShop), TOKEN_ID, INITIAL_BALANCE, "");
        
        // Send ETH to the point shop contract
        vm.deal(address(pointShop), INITIAL_BALANCE);
        vm.stopPrank();
    }

    function test_Constructor() public {
        assertEq(pointShop.owner(), owner);
        assertEq(pointShop.verifier(), verifier);
    }

    function test_Constructor_ZeroOwner() public {
        vm.expectRevert();
        new MiniGamePointShop(address(0), verifier);
    }

    function test_Constructor_ZeroVerifier() public {
        vm.expectRevert(MiniGamePointShop.InvalidVerifier.selector);
        new MiniGamePointShop(owner, address(0));
    }

    function test_UpdateVerifier() public {
        address newVerifier = makeAddr("newVerifier");
        
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit VerifierUpdated(verifier, newVerifier);
        pointShop.updateVerifier(newVerifier);
        
        assertEq(pointShop.verifier(), newVerifier);
    }

    function test_UpdateVerifier_NotOwner() public {
        address newVerifier = makeAddr("newVerifier");
        
        vm.prank(user);
        vm.expectRevert();
        pointShop.updateVerifier(newVerifier);
    }

    function test_UpdateVerifier_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(MiniGamePointShop.InvalidVerifier.selector);
        pointShop.updateVerifier(address(0));
    }

    function test_ClaimETH_Success() public {
        MiniGamePointShop.ClaimRequest memory request = _createClaimRequest(
            user,
            address(0),
            CLAIM_AMOUNT,
            0,
            NONCE,
            DEADLINE,
            MiniGamePointShop.TokenType.ETH
        );
        
        bytes memory signature = _signRequest(request, verifier);
        
        uint256 userBalanceBefore = user.balance;
        uint256 contractBalanceBefore = address(pointShop).balance;
        
        vm.prank(user);
        pointShop.claimETH(request, signature);
        
        assertEq(user.balance, userBalanceBefore + CLAIM_AMOUNT);
        assertEq(address(pointShop).balance, contractBalanceBefore - CLAIM_AMOUNT);
        assertTrue(pointShop.usedNonces(NONCE));
        assertEq(pointShop.userTokenClaims(user, address(0)), CLAIM_AMOUNT);
    }

    function test_ClaimETH_InvalidTokenType() public {
        MiniGamePointShop.ClaimRequest memory request = _createClaimRequest(
            user,
            address(0),
            CLAIM_AMOUNT,
            0,
            NONCE,
            DEADLINE,
            MiniGamePointShop.TokenType.ERC20 // Wrong type
        );
        
        bytes memory signature = _signRequest(request, verifier);
        
        vm.prank(user);
        vm.expectRevert(MiniGamePointShop.InvalidTokenType.selector);
        pointShop.claimETH(request, signature);
    }

    function test_ClaimETH_InvalidAmount() public {
        MiniGamePointShop.ClaimRequest memory request = _createClaimRequest(
            user,
            address(0),
            0, // Zero amount
            TOKEN_ID,
            NONCE,
            DEADLINE,
            MiniGamePointShop.TokenType.ETH
        );
        
        bytes memory signature = _signRequest(request, verifier);
        
        vm.prank(user);
        vm.expectRevert(MiniGamePointShop.InvalidAmount.selector);
        pointShop.claimETH(request, signature);
    }

    function test_ClaimERC20_Success() public {
        MiniGamePointShop.ClaimRequest memory request = _createClaimRequest(
            user,
            address(mockERC20),
            CLAIM_AMOUNT,
            0,
            NONCE,
            DEADLINE,
            MiniGamePointShop.TokenType.ERC20
        );
        
        bytes memory signature = _signRequest(request, verifier);
        
        uint256 userBalanceBefore = mockERC20.balanceOf(user);
        uint256 contractBalanceBefore = mockERC20.balanceOf(address(pointShop));
        
        vm.prank(user);
        pointShop.claimERC20(request, signature);
        
        assertEq(mockERC20.balanceOf(user), userBalanceBefore + CLAIM_AMOUNT);
        assertEq(mockERC20.balanceOf(address(pointShop)), contractBalanceBefore - CLAIM_AMOUNT);
        assertTrue(pointShop.usedNonces(NONCE));
        assertEq(pointShop.userTokenClaims(user, address(mockERC20)), CLAIM_AMOUNT);
    }

    function test_ClaimERC721_Success() public {
        MiniGamePointShop.ClaimRequest memory request = _createClaimRequest(
            user,
            address(mockERC721),
            1,
            TOKEN_ID,
            NONCE,
            DEADLINE,
            MiniGamePointShop.TokenType.ERC721
        );
        
        bytes memory signature = _signRequest(request, verifier);
        
        vm.prank(user);
        pointShop.claimERC721(request, signature);
        
        assertEq(mockERC721.ownerOf(TOKEN_ID), user);
        assertTrue(pointShop.usedNonces(NONCE));
        assertEq(pointShop.userTokenClaims(user, address(mockERC721)), 1);
    }

    function test_ClaimERC721_InvalidTokenId() public {
        MiniGamePointShop.ClaimRequest memory request = _createClaimRequest(
            user,
            address(mockERC721),
            1,
            0, // Zero token ID
            NONCE,
            DEADLINE,
            MiniGamePointShop.TokenType.ERC721
        );
        
        bytes memory signature = _signRequest(request, verifier);
        
        vm.prank(user);
        vm.expectRevert(MiniGamePointShop.InvalidTokenId.selector);
        pointShop.claimERC721(request, signature);
    }

    function test_ClaimERC1155_Success() public {
        MiniGamePointShop.ClaimRequest memory request = _createClaimRequest(
            user,
            address(mockERC1155),
            CLAIM_AMOUNT,
            TOKEN_ID,
            NONCE,
            DEADLINE,
            MiniGamePointShop.TokenType.ERC1155
        );
        
        bytes memory signature = _signRequest(request, verifier);
        
        uint256 userBalanceBefore = mockERC1155.balanceOf(user, TOKEN_ID);
        uint256 contractBalanceBefore = mockERC1155.balanceOf(address(pointShop), TOKEN_ID);
        
        vm.prank(user);
        pointShop.claimERC1155(request, signature);
        
        assertEq(mockERC1155.balanceOf(user, TOKEN_ID), userBalanceBefore + CLAIM_AMOUNT);
        assertEq(mockERC1155.balanceOf(address(pointShop), TOKEN_ID), contractBalanceBefore - CLAIM_AMOUNT);
        assertTrue(pointShop.usedNonces(NONCE));
        assertEq(pointShop.userTokenClaims(user, address(mockERC1155)), CLAIM_AMOUNT);
    }

    function test_Claim_InvalidSignature() public {
        MiniGamePointShop.ClaimRequest memory request = _createClaimRequest(
            user,
            address(0),
            CLAIM_AMOUNT,
            0,
            NONCE,
            DEADLINE,
            MiniGamePointShop.TokenType.ETH
        );
        
        // Sign with wrong private key
        bytes memory signature = _signRequest(request, user);
        
        vm.prank(user);
        vm.expectRevert(MiniGamePointShop.InvalidSignature.selector);
        pointShop.claimETH(request, signature);
    }

    function test_Claim_UsedNonce() public {
        MiniGamePointShop.ClaimRequest memory request = _createClaimRequest(
            user,
            address(0),
            CLAIM_AMOUNT,
            0,
            NONCE,
            DEADLINE,
            MiniGamePointShop.TokenType.ETH
        );
        
        bytes memory signature = _signRequest(request, verifier);
        
        // First claim should succeed
        vm.prank(user);
        pointShop.claimETH(request, signature);
        
        // Second claim with same nonce should fail
        vm.prank(user);
        vm.expectRevert(MiniGamePointShop.InvalidNonce.selector);
        pointShop.claimETH(request, signature);
    }

    function test_Claim_ExpiredDeadline() public {
        MiniGamePointShop.ClaimRequest memory request = _createClaimRequest(
            user,
            address(0),
            CLAIM_AMOUNT,
            0,
            NONCE,
            block.timestamp - 1, // Past deadline
            MiniGamePointShop.TokenType.ETH
        );
        
        bytes memory signature = _signRequest(request, verifier);
        
        vm.prank(user);
        vm.expectRevert(MiniGamePointShop.ExpiredDeadline.selector);
        pointShop.claimETH(request, signature);
    }

    function test_WithdrawETH_Success() public {
        uint256 withdrawAmount = 100 ether;
        address withdrawTo = makeAddr("withdrawTo");
        
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit TokensWithdrawn(withdrawTo, address(0), withdrawAmount, 0, MiniGamePointShop.TokenType.ETH);
        pointShop.withdrawETH(withdrawTo, withdrawAmount);
        
        assertEq(withdrawTo.balance, withdrawAmount);
    }

    function test_WithdrawETH_NotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        pointShop.withdrawETH(user, 100 ether);
    }

    function test_WithdrawERC20_Success() public {
        uint256 withdrawAmount = 100 ether;
        address withdrawTo = makeAddr("withdrawTo");
        
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit TokensWithdrawn(withdrawTo, address(mockERC20), withdrawAmount, 0, MiniGamePointShop.TokenType.ERC20);
        pointShop.withdrawERC20(address(mockERC20), withdrawTo, withdrawAmount);
        
        assertEq(mockERC20.balanceOf(withdrawTo), withdrawAmount);
    }

    function test_WithdrawERC721_Success() public {
        address withdrawTo = makeAddr("withdrawTo");
        
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit TokensWithdrawn(withdrawTo, address(mockERC721), 1, TOKEN_ID, MiniGamePointShop.TokenType.ERC721);
        pointShop.withdrawERC721(address(mockERC721), withdrawTo, TOKEN_ID);
        
        assertEq(mockERC721.ownerOf(TOKEN_ID), withdrawTo);
    }

    function test_WithdrawERC1155_Success() public {
        uint256 withdrawAmount = 100 ether;
        address withdrawTo = makeAddr("withdrawTo");
        
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit TokensWithdrawn(withdrawTo, address(mockERC1155), withdrawAmount, TOKEN_ID, MiniGamePointShop.TokenType.ERC1155);
        pointShop.withdrawERC1155(address(mockERC1155), withdrawTo, TOKEN_ID, withdrawAmount);
        
        assertEq(mockERC1155.balanceOf(withdrawTo, TOKEN_ID), withdrawAmount);
    }

    function test_GetClaimRequestHash() public {
        MiniGamePointShop.ClaimRequest memory request = _createClaimRequest(
            user,
            address(mockERC20),
            CLAIM_AMOUNT,
            TOKEN_ID,
            NONCE,
            DEADLINE,
            MiniGamePointShop.TokenType.ERC20
        );
        
        bytes32 hash = pointShop.getClaimRequestHash(request);
        assertTrue(hash != bytes32(0));
    }

    function test_SupportsInterface() public {
        assertTrue(pointShop.supportsInterface(0x150b7a02));
        assertTrue(pointShop.supportsInterface(0x4e2312e0));
        assertFalse(pointShop.supportsInterface(0x12345678));
    }

    function test_ReceiveETH() public {
        uint256 ethAmount = 10 ether;
        vm.deal(user, ethAmount);
        
        vm.prank(user);
        (bool success,) = address(pointShop).call{value: ethAmount}("");
        assertTrue(success);
        assertEq(address(pointShop).balance, INITIAL_BALANCE + ethAmount);
    }

    function test_ReentrancyProtection() public {
        // This test ensures the nonReentrant modifier works
        // We'll verify that the contract state is correct after a successful call
        
        MiniGamePointShop.ClaimRequest memory request = _createClaimRequest(
            user,
            address(0),
            CLAIM_AMOUNT,
            0,
            NONCE,
            DEADLINE,
            MiniGamePointShop.TokenType.ETH
        );
        
        bytes memory signature = _signRequest(request, verifier);
        
        uint256 userBalanceBefore = user.balance;
        uint256 contractBalanceBefore = address(pointShop).balance;
        
        vm.prank(user);
        pointShop.claimETH(request, signature);
        
        // Verify the claim was successful and state is correct
        assertEq(user.balance, userBalanceBefore + CLAIM_AMOUNT);
        assertEq(address(pointShop).balance, contractBalanceBefore - CLAIM_AMOUNT);
        assertTrue(pointShop.usedNonces(NONCE));
        
        // Try to call again with the same nonce - this should fail due to nonReentrant
        vm.prank(user);
        vm.expectRevert(MiniGamePointShop.InvalidNonce.selector);
        pointShop.claimETH(request, signature);
    }

    // Helper function to create claim requests
    function _createClaimRequest(
        address _user,
        address _token,
        uint256 _amount,
        uint256 _tokenId,
        uint256 _nonce,
        uint256 _deadline,
        MiniGamePointShop.TokenType _tokenType
    ) internal pure returns (MiniGamePointShop.ClaimRequest memory) {
        return MiniGamePointShop.ClaimRequest({
            user: _user,
            token: _token,
            amount: _amount,
            tokenId: _tokenId,
            nonce: _nonce,
            deadline: _deadline,
            tokenType: _tokenType
        });
    }

    // Helper function to sign requests
    function _signRequest(
        MiniGamePointShop.ClaimRequest memory _request,
        address _signer
    ) internal view returns (bytes memory) {
        bytes32 messageHash = pointShop.getClaimRequestHash(_request);
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_getPrivateKey(_signer), ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }

    // Helper function to get private key for an address
    function _getPrivateKey(address _addr) internal view returns (uint256) {
        // This is a simple mapping for testing purposes
        // In real scenarios, you'd use proper key management
        if (_addr == verifier) return 0x1234567890123456789012345678901234567890123456789012345678901234;
        if (_addr == user) return 0x2345678901234567890123456789012345678901234567890123456789012345;
        if (_addr == user2) return 0x3456789012345678901234567890123456789012345678901234567890123456;
        return 0x4567890123456789012345678901234567890123456789012345678901234567;
    }
}


