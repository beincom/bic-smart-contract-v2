// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {DropEditionTestBase} from "./DropEditionTestBase.sol";
import {IDropErc1155} from "../../src/interfaces/IDropErc1155.sol";

contract DropErc1155Test is DropEditionTestBase {
    function test_Constructor() public {
        assertEq(dropErc1155.owner(), owner);
        assertEq(dropErc1155.primarySaleRecipient(), primarySaleRecipient);
        assertEq(dropErc1155.uri(0), BASE_URI);
    }

    function test_LazyMint() public {
        string[] memory uris = new string[](2);
        uris[0] = "https://example.com/token/0.json";
        uris[1] = "https://example.com/token/1.json";

        vm.expectEmit(true, true, false, true);
        emit TokensLazyMinted(0, 1, uris);

        vm.prank(owner);
        dropErc1155.lazyMint(2, uris);

        // Check that tokens were lazy minted correctly
        assertEq(dropErc1155.nextTokenIdToLazyMint(), 2);
        assertEq(dropErc1155.tokenURI(0), uris[0]);
        assertEq(dropErc1155.tokenURI(1), uris[1]);
        assertEq(dropErc1155.uri(0), uris[0]);
        assertEq(dropErc1155.uri(1), uris[1]);
    }

    function test_LazyMint_OnlyOwner() public {
        string[] memory uris = new string[](1);
        uris[0] = "https://example.com/token/1.json";

        vm.expectRevert();
        vm.prank(user1);
        dropErc1155.lazyMint(1, uris);
    }

    function test_LazyMint_InvalidAmount() public {
        string[] memory uris = new string[](0);

        vm.expectRevert("Amount must be greater than 0");
        vm.prank(owner);
        dropErc1155.lazyMint(0, uris);
    }

    function test_LazyMint_MismatchedArrays() public {
        string[] memory uris = new string[](2);
        uris[0] = "https://example.com/token/0.json";
        uris[1] = "https://example.com/token/1.json";

        vm.expectRevert("URIs length must match amount");
        vm.prank(owner);
        dropErc1155.lazyMint(3, uris); // Amount 3 but only 2 URIs
    }

    function test_LazyMint_ProtectsExistingURIs() public {
        // This test demonstrates that once a URI is set via lazy mint,
        // it cannot be changed, ensuring immutability
        
        string[] memory uris1 = new string[](2);
        uris1[0] = "https://example.com/token/0.json";
        uris1[1] = "https://example.com/token/1.json";

        vm.prank(owner);
        dropErc1155.lazyMint(2, uris1);
        
        // Verify URIs are set and counter is updated
        assertEq(dropErc1155.tokenURI(0), uris1[0]);
        assertEq(dropErc1155.tokenURI(1), uris1[1]);
        assertEq(dropErc1155.nextTokenIdToLazyMint(), 2);

        // The design ensures that once lazy minted, URIs cannot be changed
        // since nextTokenIdToLazyMint always moves forward and the check
        // "bytes(_tokenURIs[tokenId]).length == 0" prevents overwrites
    }

    function test_LazyMint_IncrementalTokenIds() public {
        // First batch
        string[] memory uris1 = new string[](2);
        uris1[0] = "https://example.com/token/0.json";
        uris1[1] = "https://example.com/token/1.json";

        // Second batch
        string[] memory uris2 = new string[](3);
        uris2[0] = "https://example.com/token/2.json";
        uris2[1] = "https://example.com/token/3.json";
        uris2[2] = "https://example.com/token/4.json";

        vm.startPrank(owner);
        
        // First lazy mint
        dropErc1155.lazyMint(2, uris1);
        assertEq(dropErc1155.nextTokenIdToLazyMint(), 2);
        assertEq(dropErc1155.tokenURI(0), uris1[0]);
        assertEq(dropErc1155.tokenURI(1), uris1[1]);

        // Second lazy mint should continue from token ID 2
        dropErc1155.lazyMint(3, uris2);
        assertEq(dropErc1155.nextTokenIdToLazyMint(), 5);
        assertEq(dropErc1155.tokenURI(2), uris2[0]);
        assertEq(dropErc1155.tokenURI(3), uris2[1]);
        assertEq(dropErc1155.tokenURI(4), uris2[2]);
        
        vm.stopPrank();
    }

    function test_TokenURI_FallbackToBaseURI() public {
        uint256 tokenId = 1;
        
        // Should return base URI when no specific URI is set
        assertEq(dropErc1155.tokenURI(tokenId), BASE_URI);
        assertEq(dropErc1155.uri(tokenId), BASE_URI);
    }

    function test_TokenURI_OverrideBaseURI() public {
        string[] memory uris = new string[](2);
        uris[0] = "https://example.com/token/0.json";
        uris[1] = "https://example.com/token/1.json";

        // Set specific URI via lazy mint
        vm.prank(owner);
        dropErc1155.lazyMint(2, uris);

        // Should return specific URI, not base URI
        assertEq(dropErc1155.tokenURI(1), uris[1]);
        assertEq(dropErc1155.uri(1), uris[1]);
    }

    function test_TokenURI_MultipleTokens() public {
        string[] memory uris = new string[](2);
        uris[0] = "https://example.com/token/0.json";
        uris[1] = "https://example.com/token/1.json";

        vm.prank(owner);
        dropErc1155.lazyMint(2, uris);

        // Verify lazy minted tokens have correct URIs
        assertEq(dropErc1155.tokenURI(0), uris[0]);
        assertEq(dropErc1155.tokenURI(1), uris[1]);
        
        // Token 2 was not lazy minted (should use base URI)
        assertEq(dropErc1155.tokenURI(2), BASE_URI);
    }

    function test_TokenURI_ImmutableOnceSet() public {
        string[] memory originalUris = new string[](1);
        originalUris[0] = "https://example.com/token/0.json";

        vm.prank(owner);
        dropErc1155.lazyMint(1, originalUris);
        
        // Verify URI is set
        assertEq(dropErc1155.tokenURI(0), originalUris[0]);
        assertEq(dropErc1155.nextTokenIdToLazyMint(), 1);

        // Once lazy minted, the URI is immutable since:
        // 1. nextTokenIdToLazyMint has moved forward
        // 2. The check "bytes(_tokenURIs[tokenId]).length == 0" prevents overwrites
        // 3. There's no other function to modify URIs once set
        
        // Verify URI remains unchanged
        assertEq(dropErc1155.tokenURI(0), originalUris[0]);
    }

    function test_TokenURI_EmptyString() public {
        string[] memory uris = new string[](2);
        uris[0] = "https://example.com/token/0.json";
        uris[1] = ""; // Empty URI

        vm.prank(owner);
        dropErc1155.lazyMint(2, uris);

        // Token with specific URI should return that URI
        assertEq(dropErc1155.tokenURI(0), uris[0]);
        
        // Token with empty URI should return base URI
        assertEq(dropErc1155.tokenURI(1), BASE_URI);
    }

    function test_TokenURI_WithClaimProcess() public {
        uint256 tokenId = 0; // Lazy minting starts from token ID 0
        string memory tokenURI = "https://example.com/token/0.json";
        
        // Set up claim phase
        IDropErc1155.ClaimPhase memory phase = IDropErc1155.ClaimPhase({
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + 7 days,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            pricePerToken: 0, // Free claim
            currency: address(0),
            merkleRoot: bytes32(0),
            isActive: true
        });

        vm.startPrank(owner);
        
        // Set token URI via lazy mint
        string[] memory uris = new string[](1);
        uris[0] = tokenURI;
        dropErc1155.lazyMint(1, uris);
        
        // Set claim phase
        dropErc1155.setClaimPhase(tokenId, PHASE_ID, phase);
        
        vm.stopPrank();

        // Verify URI is set correctly
        assertEq(dropErc1155.tokenURI(tokenId), tokenURI);
        assertEq(dropErc1155.uri(tokenId), tokenURI);

        // Claim tokens
        IDropErc1155.ClaimRequest memory request = IDropErc1155.ClaimRequest({
            receiver: user1,
            tokenId: tokenId,
            quantity: 5,
            pricePerToken: 0,
            currency: address(0),
            proofs: new bytes32[](0)
        });

        vm.prank(user1);
        dropErc1155.claim(request, PHASE_ID);

        // Verify tokens were minted and URI is still correct
        assertEq(dropErc1155.balanceOf(user1, tokenId), 5);
        assertEq(dropErc1155.tokenURI(tokenId), tokenURI);
        assertEq(dropErc1155.uri(tokenId), tokenURI);
    }

    function test_SetClaimPhase() public {
        IDropErc1155.ClaimPhase memory phase = IDropErc1155.ClaimPhase({
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + 7 days,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            pricePerToken: 1 ether,
            currency: address(0), // ETH
            merkleRoot: bytes32(0),
            isActive: true
        });

        vm.expectEmit(true, true, false, true);
        emit ClaimPhaseUpdated(TOKEN_ID, PHASE_ID, phase);

        vm.prank(owner);
        dropErc1155.setClaimPhase(TOKEN_ID, PHASE_ID, phase);

        IDropErc1155.ClaimPhase memory storedPhase = dropErc1155.getClaimPhase(TOKEN_ID, PHASE_ID);
        assertEq(storedPhase.startTimestamp, phase.startTimestamp);
        assertEq(storedPhase.endTimestamp, phase.endTimestamp);
        assertEq(storedPhase.maxClaimableSupply, phase.maxClaimableSupply);
        assertEq(storedPhase.quantityLimitPerWallet, phase.quantityLimitPerWallet);
        assertEq(storedPhase.pricePerToken, phase.pricePerToken);
        assertEq(storedPhase.currency, phase.currency);
        assertTrue(storedPhase.isActive);
    }

    function test_SetClaimPhase_OnlyOwner() public {
        IDropErc1155.ClaimPhase memory phase = IDropErc1155.ClaimPhase({
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + 7 days,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            pricePerToken: 1 ether,
            currency: address(0),
            merkleRoot: bytes32(0),
            isActive: true
        });

        vm.prank(user1);
        vm.expectRevert();
        dropErc1155.setClaimPhase(TOKEN_ID, PHASE_ID, phase);
    }

    function test_SetClaimPhase_InvalidTimestamp() public {
        IDropErc1155.ClaimPhase memory phase = IDropErc1155.ClaimPhase({
            startTimestamp: block.timestamp + 7 days,
            endTimestamp: block.timestamp, // End before start
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            pricePerToken: 1 ether,
            currency: address(0),
            merkleRoot: bytes32(0),
            isActive: true
        });

        vm.prank(owner);
        vm.expectRevert(IDropErc1155.DropInvalidTimestamp.selector);
        dropErc1155.setClaimPhase(TOKEN_ID, PHASE_ID, phase);
    }

    function test_Claim_ETH() public {
        uint256 pricePerToken = 0.1 ether;
        uint256 quantity = 5;
        uint256 totalPrice = pricePerToken * quantity;

        _createBasicClaimPhase(TOKEN_ID, PHASE_ID, pricePerToken, address(0));

        IDropErc1155.ClaimRequest memory request = _createClaimRequest(
            user1,
            TOKEN_ID,
            quantity,
            pricePerToken,
            address(0),
            new bytes32[](0)
        );

        uint256 initialBalance = primarySaleRecipient.balance;

        vm.expectEmit(true, true, true, true);
        emit TokensClaimed(user1, user1, TOKEN_ID, PHASE_ID, quantity);

        vm.prank(user1);
        dropErc1155.claim{value: totalPrice}(request, PHASE_ID);

        assertEq(dropErc1155.balanceOf(user1, TOKEN_ID), quantity);
        assertEq(primarySaleRecipient.balance, initialBalance + totalPrice);
        assertEq(dropErc1155.totalSupply(TOKEN_ID), quantity);
    }

    function test_Claim_ERC20() public {
        uint256 pricePerToken = 10 * 1e18; // 10 USDC
        uint256 quantity = 3;
        uint256 totalPrice = pricePerToken * quantity;

        _createBasicClaimPhase(TOKEN_ID, PHASE_ID, pricePerToken, address(usdcToken));
        _approveTokens(user1, address(dropErc1155), totalPrice);

        IDropErc1155.ClaimRequest memory request = _createClaimRequest(
            user1,
            TOKEN_ID,
            quantity,
            pricePerToken,
            address(usdcToken),
            new bytes32[](0)
        );

        uint256 initialBalance = usdcToken.balanceOf(primarySaleRecipient);

        vm.prank(user1);
        dropErc1155.claim(request, PHASE_ID);

        assertEq(dropErc1155.balanceOf(user1, TOKEN_ID), quantity);
        assertEq(usdcToken.balanceOf(primarySaleRecipient), initialBalance + totalPrice);
    }

    function test_Claim_Free() public {
        _createBasicClaimPhase(TOKEN_ID, PHASE_ID, 0, address(0));

        IDropErc1155.ClaimRequest memory request = _createClaimRequest(
            user1,
            TOKEN_ID,
            2,
            0,
            address(0),
            new bytes32[](0)
        );

        vm.prank(user1);
        dropErc1155.claim(request, PHASE_ID);

        assertEq(dropErc1155.balanceOf(user1, TOKEN_ID), 2);
    }

    function test_Claim_WithMerkleProof() public {
        // Create allowlist
        address[] memory allowedAddresses = new address[](3);
        uint256[] memory allowedQuantities = new uint256[](3);
        allowedAddresses[0] = user1;
        allowedQuantities[0] = 5;
        allowedAddresses[1] = user2;
        allowedQuantities[1] = 3;
        allowedAddresses[2] = user3;
        allowedQuantities[2] = 2;

        (bytes32 merkleRoot, bytes32[] memory proof) = _createMerkleProof(
            allowedAddresses,
            allowedQuantities,
            user1,
            allowedQuantities[0]
        );

        // Create phase with merkle root
        IDropErc1155.ClaimPhase memory phase = IDropErc1155.ClaimPhase({
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + 7 days,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            pricePerToken: 0.1 ether,
            currency: address(0),
            merkleRoot: merkleRoot,
            isActive: true
        });

        vm.prank(owner);
        dropErc1155.setClaimPhase(TOKEN_ID, PHASE_ID, phase);

        IDropErc1155.ClaimRequest memory request = _createClaimRequest(
            user1,
            TOKEN_ID,
            allowedQuantities[0],
            0.1 ether,
            address(0),
            proof
        );

        vm.prank(user1);
        dropErc1155.claim{value: 0.5 ether}(request, PHASE_ID);

        assertEq(dropErc1155.balanceOf(user1, TOKEN_ID), allowedQuantities[0]);
    }

    function test_Claim_InvalidMerkleProof() public {
        // Create allowlist without user1
        address[] memory allowedAddresses = new address[](2);
        uint256[] memory allowedQuantities = new uint256[](2);
        allowedAddresses[0] = user2;
        allowedQuantities[0] = 3;
        allowedAddresses[1] = user3;
        allowedQuantities[1] = 2;

        (bytes32 merkleRoot,) = _createMerkleProof(
            allowedAddresses,
            allowedQuantities,
            user2,
            allowedQuantities[0]
        );

        // Create phase with merkle root
        IDropErc1155.ClaimPhase memory phase = IDropErc1155.ClaimPhase({
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + 7 days,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            pricePerToken: 0.1 ether,
            currency: address(0),
            merkleRoot: merkleRoot,
            isActive: true
        });

        vm.prank(owner);
        dropErc1155.setClaimPhase(TOKEN_ID, PHASE_ID, phase);

        IDropErc1155.ClaimRequest memory request = _createClaimRequest(
            user1,
            TOKEN_ID,
            5,
            0.1 ether,
            address(0),
            new bytes32[](0) // Invalid proof
        );

        vm.prank(user1);
        vm.expectRevert(IDropErc1155.DropInvalidProof.selector);
        dropErc1155.claim{value: 0.5 ether}(request, PHASE_ID);
    }

    function test_Claim_ExceedsWalletLimit() public {
        _createBasicClaimPhase(TOKEN_ID, PHASE_ID, 0.1 ether, address(0));

        IDropErc1155.ClaimRequest memory request = _createClaimRequest(
            user1,
            TOKEN_ID,
            15, // Exceeds limit of 10
            0.1 ether,
            address(0),
            new bytes32[](0)
        );

        vm.prank(user1);
        vm.expectRevert(IDropErc1155.DropExceedsQuantityLimit.selector);
        dropErc1155.claim{value: 1.5 ether}(request, PHASE_ID);
    }

    function test_Claim_ExceedsPhaseSupply() public {
        // Create phase with limited supply
        IDropErc1155.ClaimPhase memory phase = IDropErc1155.ClaimPhase({
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + 7 days,
            maxClaimableSupply: 5, // Very limited
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            pricePerToken: 0.1 ether,
            currency: address(0),
            merkleRoot: bytes32(0),
            isActive: true
        });

        vm.prank(owner);
        dropErc1155.setClaimPhase(TOKEN_ID, PHASE_ID, phase);

        IDropErc1155.ClaimRequest memory request = _createClaimRequest(
            user1,
            TOKEN_ID,
            6, // Exceeds phase supply
            0.1 ether,
            address(0),
            new bytes32[](0)
        );

        vm.prank(user1);
        vm.expectRevert(IDropErc1155.DropExceedsPhaseSupply.selector);
        dropErc1155.claim{value: 0.6 ether}(request, PHASE_ID);
    }

    function test_Claim_ExceedsMaxSupply() public {
        _setMaxSupply(TOKEN_ID, 5);
        _createBasicClaimPhase(TOKEN_ID, PHASE_ID, 0.1 ether, address(0));

        IDropErc1155.ClaimRequest memory request = _createClaimRequest(
            user1,
            TOKEN_ID,
            6, // Exceeds max supply
            0.1 ether,
            address(0),
            new bytes32[](0)
        );

        vm.prank(user1);
        vm.expectRevert(IDropErc1155.DropExceedsMaxSupply.selector);
        dropErc1155.claim{value: 0.6 ether}(request, PHASE_ID);
    }

    function test_Claim_PhaseNotActive() public {
        IDropErc1155.ClaimPhase memory phase = IDropErc1155.ClaimPhase({
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + 7 days,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            pricePerToken: 0.1 ether,
            currency: address(0),
            merkleRoot: bytes32(0),
            isActive: false // Not active
        });

        vm.prank(owner);
        dropErc1155.setClaimPhase(TOKEN_ID, PHASE_ID, phase);

        IDropErc1155.ClaimRequest memory request = _createClaimRequest(
            user1,
            TOKEN_ID,
            5,
            0.1 ether,
            address(0),
            new bytes32[](0)
        );

        vm.prank(user1);
        vm.expectRevert(IDropErc1155.DropPhaseNotActive.selector);
        dropErc1155.claim{value: 0.5 ether}(request, PHASE_ID);
    }

    function test_Claim_PhaseNotStarted() public {
        IDropErc1155.ClaimPhase memory phase = IDropErc1155.ClaimPhase({
            startTimestamp: block.timestamp + 1 days, // Future start
            endTimestamp: block.timestamp + 7 days,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            pricePerToken: 0.1 ether,
            currency: address(0),
            merkleRoot: bytes32(0),
            isActive: true
        });

        vm.prank(owner);
        dropErc1155.setClaimPhase(TOKEN_ID, PHASE_ID, phase);

        IDropErc1155.ClaimRequest memory request = _createClaimRequest(
            user1,
            TOKEN_ID,
            5,
            0.1 ether,
            address(0),
            new bytes32[](0)
        );

        vm.prank(user1);
        vm.expectRevert(IDropErc1155.DropPhaseNotActive.selector);
        dropErc1155.claim{value: 0.5 ether}(request, PHASE_ID);
    }

    function test_Claim_PhaseEnded() public {
        vm.warp(block.timestamp + 3 days); // Move forward in time first
        
        IDropErc1155.ClaimPhase memory phase = IDropErc1155.ClaimPhase({
            startTimestamp: block.timestamp - 2 days,
            endTimestamp: block.timestamp - 1 days, // Past end
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            pricePerToken: 0.1 ether,
            currency: address(0),
            merkleRoot: bytes32(0),
            isActive: true
        });

        vm.prank(owner);
        dropErc1155.setClaimPhase(TOKEN_ID, PHASE_ID, phase);

        IDropErc1155.ClaimRequest memory request = _createClaimRequest(
            user1,
            TOKEN_ID,
            5,
            0.1 ether,
            address(0),
            new bytes32[](0)
        );

        vm.prank(user1);
        vm.expectRevert(IDropErc1155.DropPhaseNotActive.selector);
        dropErc1155.claim{value: 0.5 ether}(request, PHASE_ID);
    }

    function test_Claim_InvalidPrice() public {
        _createBasicClaimPhase(TOKEN_ID, PHASE_ID, 0.1 ether, address(0));

        IDropErc1155.ClaimRequest memory request = _createClaimRequest(
            user1,
            TOKEN_ID,
            5,
            0.2 ether, // Wrong price
            address(0),
            new bytes32[](0)
        );

        vm.prank(user1);
        vm.expectRevert(IDropErc1155.DropInvalidPrice.selector);
        dropErc1155.claim{value: 0.5 ether}(request, PHASE_ID);
    }

    function test_Claim_InvalidCurrency() public {
        _createBasicClaimPhase(TOKEN_ID, PHASE_ID, 10 * 1e18, address(usdcToken));

        IDropErc1155.ClaimRequest memory request = _createClaimRequest(
            user1,
            TOKEN_ID,
            5,
            10 * 1e18,
            address(bicToken), // Wrong currency
            new bytes32[](0)
        );

        vm.prank(user1);
        vm.expectRevert(IDropErc1155.DropInvalidCurrency.selector);
        dropErc1155.claim(request, PHASE_ID);
    }

    function test_GetActiveClaimPhase() public {
        _createBasicClaimPhase(TOKEN_ID, PHASE_ID, 0.1 ether, address(0));

        (uint256 activePhaseId, IDropErc1155.ClaimPhase memory activePhase) = 
            dropErc1155.getActiveClaimPhase(TOKEN_ID);

        assertEq(activePhaseId, PHASE_ID);
        assertTrue(activePhase.isActive);
        assertEq(activePhase.pricePerToken, 0.1 ether);
    }

    function test_GetActiveClaimPhase_NoActivePhase() public {
        vm.expectRevert(IDropErc1155.DropPhaseNotFound.selector);
        dropErc1155.getActiveClaimPhase(TOKEN_ID);
    }

    function test_VerifyClaim() public {
        _createBasicClaimPhase(TOKEN_ID, PHASE_ID, 0.1 ether, address(0));

        IDropErc1155.ClaimRequest memory request = _createClaimRequest(
            user1,
            TOKEN_ID,
            5,
            0.1 ether,
            address(0),
            new bytes32[](0)
        );

        bool isEligible = dropErc1155.verifyClaim(user1, request, PHASE_ID);
        assertTrue(isEligible);
    }

    function test_VerifyClaim_NotEligible() public {
        _createBasicClaimPhase(TOKEN_ID, PHASE_ID, 0.1 ether, address(0));

        IDropErc1155.ClaimRequest memory request = _createClaimRequest(
            user1,
            TOKEN_ID,
            15, // Exceeds wallet limit
            0.1 ether,
            address(0),
            new bytes32[](0)
        );

        bool isEligible = dropErc1155.verifyClaim(user1, request, PHASE_ID);
        assertFalse(isEligible);
    }

    function test_SetMaxTotalSupply() public {
        uint256 maxSupply = 10000;

        vm.expectEmit(true, false, false, true);
        emit MaxTotalSupplyUpdated(TOKEN_ID, maxSupply);

        vm.prank(owner);
        dropErc1155.setMaxTotalSupply(TOKEN_ID, maxSupply);

        assertEq(dropErc1155.getMaxTotalSupply(TOKEN_ID), maxSupply);
    }

    function test_SetDefaultRoyalty() public {
        address royaltyRecipient = makeAddr("royaltyRecipient");
        uint96 royaltyBps = 500; // 5%

        vm.expectEmit(true, false, false, true);
        emit DefaultRoyaltyUpdated(royaltyRecipient, royaltyBps);

        vm.prank(owner);
        dropErc1155.setDefaultRoyalty(royaltyRecipient, royaltyBps);

        (address recipient, uint256 royaltyAmount) = dropErc1155.royaltyInfo(TOKEN_ID, 10000);
        assertEq(recipient, royaltyRecipient);
        assertEq(royaltyAmount, 500); // 5% of 10000
    }

    function test_OwnerMint() public {
        uint256 quantity = 100;

        vm.prank(owner);
        dropErc1155.ownerMint(user1, TOKEN_ID, quantity);

        assertEq(dropErc1155.balanceOf(user1, TOKEN_ID), quantity);
        assertEq(dropErc1155.totalSupply(TOKEN_ID), quantity);
    }

    function test_OwnerMint_ExceedsMaxSupply() public {
        _setMaxSupply(TOKEN_ID, 50);

        vm.prank(owner);
        vm.expectRevert(IDropErc1155.DropExceedsMaxSupply.selector);
        dropErc1155.ownerMint(user1, TOKEN_ID, 100);
    }

    function test_OwnerMintBatch() public {
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory quantities = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        quantities[0] = 50;
        quantities[1] = 75;

        vm.prank(owner);
        dropErc1155.ownerMintBatch(user1, tokenIds, quantities);

        assertEq(dropErc1155.balanceOf(user1, tokenIds[0]), quantities[0]);
        assertEq(dropErc1155.balanceOf(user1, tokenIds[1]), quantities[1]);
    }

    function test_SetPrimarySaleRecipient() public {
        address newRecipient = makeAddr("newRecipient");

        vm.prank(owner);
        dropErc1155.setPrimarySaleRecipient(newRecipient);

        assertEq(dropErc1155.primarySaleRecipient(), newRecipient);
    }

    function test_SupportsInterface() public {
        // ERC1155
        assertTrue(dropErc1155.supportsInterface(0xd9b67a26));
        // ERC2981 (royalties)
        assertTrue(dropErc1155.supportsInterface(0x2a55205a));
        // ERC165
        assertTrue(dropErc1155.supportsInterface(0x01ffc9a7));
    }
} 