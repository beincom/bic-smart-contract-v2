// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {BicPack} from "src/pack/BicPack.sol";
import {BicTokenPaymasterWithoutPreSetupExchange} from "test/contracts/BicTokenPaymasterWithoutPreSetupExchange.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ITokenBundle} from "src/extension/interface/ITokenBundle.sol";

// Mock ERC721 Token
contract MockERC721 is ERC721 {

    constructor() ERC721("MockNFT", "MNFT") {
    }

    function mint(address to, uint256 tokenId) external {
        require(to != address(0), "Invalid address");
        _mint(to, tokenId);
    }
}

// Mock ERC1155 Token
contract MockERC1155 is ERC1155 {
    constructor() ERC1155("https://mock.uri/") {
    }

    function mint(address to, uint256 tokenId, uint256 amount) external {
        require(to != address(0), "Invalid address");
        _mint(to, tokenId, amount, "");
    }
}

contract BicPackTest is Test {
    BicPack public pack;
    BicTokenPaymasterWithoutPreSetupExchange public bicToken;
    MockERC721 public erc721;
    MockERC1155 public erc1155;
    
    address public owner = address(0xABCD);
    address public user = address(0xBEEF);
    address public recipient = address(0xCAFE);
    
    ITokenBundle.Token[] public contents;
    uint256[] public numOfRewardUnits;

    function setUp() public {
        // Deploy the real BIC token with required constructor parameters
        address entryPoint = address(0x123); // Mock entry point
        address superController = owner;
        address[] memory signers = new address[](1);
        signers[0] = owner;
        
        bicToken = new BicTokenPaymasterWithoutPreSetupExchange(entryPoint, superController, signers);
        erc721 = new MockERC721();
        erc1155 = new MockERC1155();
        
        pack = new BicPack("BicPack", "BIC-PACK", "https://pack.uri/", owner);
        
        // Setup mock tokens with balances
        // BIC token already minted to superController (owner) in constructor
        erc721.mint(owner, 1);
        erc721.mint(owner, 2);
        erc1155.mint(owner, 1, 150);
        erc1155.mint(owner, 2, 50);
        
        // Approve pack contract to spend tokens
        vm.prank(owner);
        bicToken.approve(address(pack), type(uint256).max);
        vm.prank(owner);
        erc721.setApprovalForAll(address(pack), true);
        vm.prank(owner);
        erc1155.setApprovalForAll(address(pack), true);
        
        // Also approve for recipient
        vm.prank(recipient);
        bicToken.approve(address(pack), type(uint256).max);
        vm.prank(recipient);
        erc721.setApprovalForAll(address(pack), true);
        vm.prank(recipient);
        erc1155.setApprovalForAll(address(pack), true);
    }

    function testCreatePackWithERC20() public {
        // Setup pack contents with ERC20 tokens
        contents = new ITokenBundle.Token[](1);
        contents[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 100 * 10**18
        });

        numOfRewardUnits = new uint256[](1);
        numOfRewardUnits[0] = 10; // 10 reward units (divisible by 2)

        vm.prank(owner);
        (uint256 packId, uint256 packTotalSupply) = pack.createPack(
            contents,
            numOfRewardUnits,
            "https://pack.uri/",
            uint128(block.timestamp),
            uint128(2), // 2 reward units per open
            recipient
        );

        assertEq(packId, 0);
        assertEq(packTotalSupply, 5); // 10 reward units / 2 per open = 5 packs
        assertEq(pack.balanceOf(recipient, packId), 5);
        assertEq(pack.canUpdatePack(packId), true);
    }

    function testCreatePackWithMultipleTokenTypes() public {
        // Setup pack contents with multiple token types
        contents = new ITokenBundle.Token[](3);
        contents[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 100 * 10**18
        });
        contents[1] = ITokenBundle.Token({
            assetContract: address(erc721),
            tokenType: ITokenBundle.TokenType.ERC721,
            tokenId: 1,
            totalAmount: 1
        });
        contents[2] = ITokenBundle.Token({
            assetContract: address(erc1155),
            tokenType: ITokenBundle.TokenType.ERC1155,
            tokenId: 1,
            totalAmount: 70
        });

        numOfRewardUnits = new uint256[](3);
        numOfRewardUnits[0] = 8; // 8 ERC20 reward units (divisible by 4)
        numOfRewardUnits[1] = 1;  // 1 ERC721 reward unit
        numOfRewardUnits[2] = 7;  // 7 ERC1155 reward units (total 16)

        vm.prank(owner);
        (uint256 packId, uint256 packTotalSupply) = pack.createPack(
            contents,
            numOfRewardUnits,
            "https://pack.uri/",
            uint128(block.timestamp),
            uint128(4), // 4 reward units per open
            recipient
        );

        assertEq(packId, 0);
        assertEq(packTotalSupply, 4); // 16 total reward units / 4 per open = 4 packs
        assertEq(pack.balanceOf(recipient, packId), 4);

        ITokenBundle.Token[] memory newContents = new ITokenBundle.Token[](1);
        newContents[0] = ITokenBundle.Token({
            assetContract: address(erc1155),
            tokenType: ITokenBundle.TokenType.ERC1155,
            tokenId: 1,
            totalAmount: 80
        });
        uint256[] memory newNumOfRewardUnits = new uint256[](1);
        newNumOfRewardUnits[0] = 4;
        vm.prank(owner);
        (uint256 newPackTotalSupply, uint256 newSupplyAdded) = pack.addPackContents(packId, newContents,newNumOfRewardUnits, recipient);
        assertEq(pack.canUpdatePack(packId), true); // Can still update pack after adding contents
        assertEq(newPackTotalSupply, 5);
        assertEq(pack.balanceOf(recipient, packId), 5);

    }

    function testCreatePackRevertsWhenNotOwner() public {
        contents = new ITokenBundle.Token[](1);
        contents[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 100 * 10**18
        });

        numOfRewardUnits = new uint256[](1);
        numOfRewardUnits[0] = 10;

        vm.prank(user);
        vm.expectRevert();
        pack.createPack(
            contents,
            numOfRewardUnits,
            "https://pack.uri/",
            uint128(block.timestamp),
            uint128(2),
            recipient
        );
    }

    function testCreatePackRevertsWithEmptyContents() public {
        contents = new ITokenBundle.Token[](0);
        numOfRewardUnits = new uint256[](0);

        vm.prank(owner);
        vm.expectRevert();
        pack.createPack(
            contents,
            numOfRewardUnits,
            "https://pack.uri/",
            uint128(block.timestamp),
            uint128(2),
            recipient
        );
    }

    function testCreatePackRevertsWithMismatchedLengths() public {
        contents = new ITokenBundle.Token[](2);
        contents[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 100 * 10**18
        });
        contents[1] = ITokenBundle.Token({
            assetContract: address(erc721),
            tokenType: ITokenBundle.TokenType.ERC721,
            tokenId: 1,
            totalAmount: 1
        });

        numOfRewardUnits = new uint256[](1);
        numOfRewardUnits[0] = 10;

        vm.prank(owner);
        vm.expectRevert();
        pack.createPack(
            contents,
            numOfRewardUnits,
            "https://pack.uri/",
            uint128(block.timestamp),
            uint128(2),
            recipient
        );
    }

    function testOpenPackSuccess() public {
        // First create a pack
        contents = new ITokenBundle.Token[](2);
        contents[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 90 * 10**18
        });
        contents[1] = ITokenBundle.Token({
            assetContract: address(erc721),
            tokenType: ITokenBundle.TokenType.ERC721,
            tokenId: 1,
            totalAmount: 1
        });

        numOfRewardUnits = new uint256[](2);
        numOfRewardUnits[0] = 9;
        numOfRewardUnits[1] = 1;
        vm.prank(owner);
        (uint256 packId,  uint256 packTotalSupply) = pack.createPack(
            contents,
            numOfRewardUnits,
            "https://pack.uri/",
            uint128(block.timestamp),
            uint128(2),
            recipient
        );
        assertEq(packTotalSupply, 5); // 10 total reward units / 2 per open = 5 packs

        // Transfer pack to user
        vm.prank(recipient);
        pack.safeTransferFrom(recipient, user, packId, 1, "");

        uint256 tBalance = bicToken.balanceOf(address (pack));
        // Check initial balance of pack
        assertEq(tBalance, 90 * 10**18); // Pack holds 90 BIC
        // User opens pack
        vm.prank(user);
        ITokenBundle.Token[] memory rewardUnits = pack.openPack(packId, 1);

        assertEq(rewardUnits.length, 2); // 2 reward units per open
        assertEq(pack.balanceOf(user, packId), 0); // Pack was burned
        assertEq(pack.canUpdatePack(packId), false); // Can no longer update after transfer
    }

    function testOpenPackRevertsWhenInsufficientBalance() public {
        // Create pack
        contents = new ITokenBundle.Token[](1);
        contents[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 100 * 10**18
        });

        numOfRewardUnits = new uint256[](1);
        numOfRewardUnits[0] = 10;

        vm.prank(owner);
        (uint256 packId,) = pack.createPack(
            contents,
            numOfRewardUnits,
            "https://pack.uri/",
            uint128(block.timestamp),
            uint128(2),
            recipient
        );

        // Transfer to user
        vm.prank(recipient);
        pack.safeTransferFrom(recipient, user, packId, 1, "");

        // Try to open more packs than owned
        vm.prank(user);
        vm.expectRevert();
        pack.openPack(packId, 2);
    }

    function testOpenPackRevertsBeforeOpenStartTimestamp() public {
        // Create pack with future open start time
        contents = new ITokenBundle.Token[](1);
        contents[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 100 * 10**18
        });

        numOfRewardUnits = new uint256[](1);
        numOfRewardUnits[0] = 10;

        vm.prank(owner);
        (uint256 packId,) = pack.createPack(
            contents,
            numOfRewardUnits,
            "https://pack.uri/",
            uint128(block.timestamp + 1000), // Future time
            uint128(2),
            recipient
        );

        // Transfer to user
        vm.prank(recipient);
        pack.safeTransferFrom(recipient, user, packId, 1, "");

        // Try to open before start time
        vm.prank(user);
        vm.expectRevert();
        pack.openPack(packId, 1);
    }

    function testOpenPackAfterStartTimestamp() public {
        // Create pack with current open start time
        contents = new ITokenBundle.Token[](1);
        contents[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 100 * 10**18
        });

        numOfRewardUnits = new uint256[](1);
        numOfRewardUnits[0] = 10;

        vm.prank(owner);
        (uint256 packId,) = pack.createPack(
            contents,
            numOfRewardUnits,
            "https://pack.uri/",
            uint128(block.timestamp),
            uint128(2),
            recipient
        );

        // Transfer to user
        vm.prank(recipient);
        pack.safeTransferFrom(recipient, user, packId, 1, "");

        // Advance time
        vm.warp(block.timestamp + 100);

        // Open pack after start time
        vm.prank(user);
        ITokenBundle.Token[] memory rewardUnits = pack.openPack(packId, 1);

        assertEq(rewardUnits.length, 2);
        assertEq(pack.balanceOf(user, packId), 0);
    }

    function testOpenMultiplePacks() public {
        // Create pack
        contents = new ITokenBundle.Token[](1);
        contents[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 100 * 10**18
        });

        numOfRewardUnits = new uint256[](1);
        numOfRewardUnits[0] = 10;

        vm.prank(owner);
        (uint256 packId,) = pack.createPack(
            contents,
            numOfRewardUnits,
            "https://pack.uri/",
            uint128(block.timestamp),
            uint128(2),
            recipient
        );

        // Transfer 3 packs to user
        vm.prank(recipient);
        pack.safeTransferFrom(recipient, user, packId, 3, "");

        // Open 2 packs
        vm.prank(user);
        ITokenBundle.Token[] memory rewardUnits = pack.openPack(packId, 2);

        assertEq(rewardUnits.length, 4); // 2 packs * 2 reward units per pack
        assertEq(pack.balanceOf(user, packId), 1); // 3 - 2 = 1 remaining
    }

    function testGetPackContents() public {
        // Create pack
        contents = new ITokenBundle.Token[](2);
        contents[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 90 * 10**18
        });
        contents[1] = ITokenBundle.Token({
            assetContract: address(erc721),
            tokenType: ITokenBundle.TokenType.ERC721,
            tokenId: 1,
            totalAmount: 1
        });

        numOfRewardUnits = new uint256[](2);
        numOfRewardUnits[0] = 9; // Changed to make total divisible by 2
        numOfRewardUnits[1] = 1; // Changed to make total divisible by 2

        vm.prank(owner);
        (uint256 packId,) = pack.createPack(
            contents,
            numOfRewardUnits,
            "https://pack.uri/",
            uint128(block.timestamp),
            uint128(2),
            recipient
        );

        // Get pack contents
        (ITokenBundle.Token[] memory retrievedContents, uint256[] memory perUnitAmounts) = pack.getPackContents(packId);

        assertEq(retrievedContents.length, 2);
        assertEq(retrievedContents[0].assetContract, address(bicToken));
        assertTrue(retrievedContents[0].tokenType == ITokenBundle.TokenType.ERC20);
        assertEq(retrievedContents[0].totalAmount, 90 * 10**18);
        assertEq(retrievedContents[1].assetContract, address(erc721));
        assertTrue(retrievedContents[1].tokenType == ITokenBundle.TokenType.ERC721);
        assertEq(retrievedContents[1].tokenId, 1);
        assertEq(retrievedContents[1].totalAmount, 1);

        assertEq(perUnitAmounts.length, 2);
        assertEq(perUnitAmounts[0], 10 * 10**18); // 100 * 10**18 / 10
        assertEq(perUnitAmounts[1], 1); // 1 / 1
    }

    function testPackTotalSupplyTracking() public {
        // Create pack
        contents = new ITokenBundle.Token[](1);
        contents[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 100 * 10**18
        });

        numOfRewardUnits = new uint256[](1);
        numOfRewardUnits[0] = 10;

        vm.prank(owner);
        (uint256 packId, uint256 packTotalSupply) = pack.createPack(
            contents,
            numOfRewardUnits,
            "https://pack.uri/",
            uint128(block.timestamp),
            uint128(2),
            recipient
        );

        assertEq(pack.totalSupply(packId), packTotalSupply);
        assertEq(pack.totalSupply(packId), 5); // 10 reward units / 2 per open = 5 packs

        // Transfer some packs
        vm.prank(recipient);
        pack.safeTransferFrom(recipient, user, packId, 2, "");

        // Open packs
        vm.prank(user);
        pack.openPack(packId, 1);

        assertEq(pack.totalSupply(packId), 4); // 5 - 1 = 4 remaining
    }
} 