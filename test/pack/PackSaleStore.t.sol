// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {PackSaleStore} from "src/pack/PackSaleStore.sol";
import {BicTokenPaymasterWithoutPreSetupExchange} from "test/contracts/BicTokenPaymasterWithoutPreSetupExchange.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ITokenBundle} from "src/extension/interface/ITokenBundle.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Mock ERC721 Token
contract MockERC721 is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) external {
        require(to != address(0), "Invalid address");
        _mint(to, tokenId);
    }
}

// Mock ERC1155 Token
contract MockERC1155 is ERC1155 {
    constructor() ERC1155("https://mock.uri/") {}

    function mint(address to, uint256 tokenId, uint256 amount) external {
        require(to != address(0), "Invalid address");
        _mint(to, tokenId, amount, "");
    }
}

contract PackSaleStoreTest is Test {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    PackSaleStore public packStore;
    BicTokenPaymasterWithoutPreSetupExchange public bicToken;
    MockERC721 public erc721;
    MockERC1155 public erc1155;
    
    address public owner = address(0xABCD);
    address public operator = address(0xDCBA);
    address public user = address(0xBEEF);
    address public attacker = address(0xBAD);
    
    uint256 public operatorPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
    uint256 public attackerPrivateKey = 0x9876543210987654321098765432109876543210987654321098765432109876;

    ITokenBundle.Token[] public packageAssets;

    function setUp() public {
        // Set operator address to match private key
        operator = vm.addr(operatorPrivateKey);
        
        // Deploy contracts
        address entryPoint = address(0x123);
        address superController = owner;
        address[] memory signers = new address[](1);
        signers[0] = owner;
        
        bicToken = new BicTokenPaymasterWithoutPreSetupExchange(entryPoint, superController, signers);
        erc721 = new MockERC721();
        erc1155 = new MockERC1155();
        
        packStore = new PackSaleStore(owner, operator);
        
        // Setup tokens and balances
        erc721.mint(owner, 1);
        erc721.mint(owner, 2);
        erc1155.mint(owner, 1, 100);
        erc1155.mint(owner, 2, 50);
        
        // Give user some tokens for payments
        vm.deal(user, 10 ether);
        vm.prank(owner);
        bicToken.transfer(user, 1000 * 10**18);
        
        // Approve packStore to spend tokens
        vm.prank(owner);
        bicToken.approve(address(packStore), type(uint256).max);
        vm.prank(owner);
        erc721.setApprovalForAll(address(packStore), true);
        vm.prank(owner);
        erc1155.setApprovalForAll(address(packStore), true);
        
        vm.prank(user);
        bicToken.approve(address(packStore), type(uint256).max);
    }

    function testConstructorSetsOwnerAndOperator() public {
        assertEq(packStore.owner(), owner);
        assertEq(packStore.operator(), operator);
    }

    function testConstructorRevertsWithZeroOperator() public {
        vm.expectRevert(PackSaleStore.ZeroAddress.selector);
        new PackSaleStore(owner, address(0));
    }

    function testRegisterPackageSuccess() public {
        // Setup package assets
        packageAssets = new ITokenBundle.Token[](2);
        packageAssets[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 100 * 10**18
        });
        packageAssets[1] = ITokenBundle.Token({
            assetContract: address(erc721),
            tokenType: ITokenBundle.TokenType.ERC721,
            tokenId: 1,
            totalAmount: 1
        });

        vm.prank(owner);
        uint256 packageId = packStore.registerPackage(
            10, // capacity
            packageAssets,
            1 ether, // price
            address(0) // ETH payment
        );

        assertEq(packageId, 0);
        assertEq(packStore.nextPackageId(), 1);

        PackSaleStore.PackageInfo memory packageInfo = packStore.getPackageInfo(packageId);
        assertEq(packageInfo.capacity, 10);
        assertEq(packageInfo.sold, 0);
        assertEq(packageInfo.price, 1 ether);
        assertEq(packageInfo.currency, address(0));
        assertTrue(packageInfo.active);
    }

    function testRegisterPackageRevertsWithZeroCapacity() public {
        packageAssets = new ITokenBundle.Token[](1);
        packageAssets[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 100 * 10**18
        });

        vm.prank(owner);
        vm.expectRevert(PackSaleStore.InvalidCapacity.selector);
        packStore.registerPackage(0, packageAssets, 1 ether, address(0));
    }

    function testRegisterPackageRevertsWithEmptyAssets() public {
        packageAssets = new ITokenBundle.Token[](0);

        vm.prank(owner);
        vm.expectRevert(PackSaleStore.EmptyAssets.selector);
        packStore.registerPackage(10, packageAssets, 1 ether, address(0));
    }

    function testRegisterPackageRevertsWhenNotOwner() public {
        packageAssets = new ITokenBundle.Token[](1);
        packageAssets[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 100 * 10**18
        });

        vm.prank(user);
        vm.expectRevert();
        packStore.registerPackage(10, packageAssets, 1 ether, address(0));
    }

    function testSetOperatorSuccess() public {
        address newOperator = address(0x1111);
        
        vm.prank(owner);
        packStore.setOperator(newOperator);
        
        assertEq(packStore.operator(), newOperator);
    }

    function testSetOperatorRevertsWithZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(PackSaleStore.ZeroAddress.selector);
        packStore.setOperator(address(0));
    }

    function testSetOperatorRevertsWhenNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        packStore.setOperator(address(0x1111));
    }

    function testDeactivateAndReactivatePackage() public {
        uint256 packageId = _createTestPackage();

        // Deactivate
        vm.prank(owner);
        packStore.deactivatePackage(packageId);
        
        PackSaleStore.PackageInfo memory packageInfo = packStore.getPackageInfo(packageId);
        assertFalse(packageInfo.active);

        // Reactivate
        vm.prank(owner);
        packStore.reactivatePackage(packageId);
        
        packageInfo = packStore.getPackageInfo(packageId);
        assertTrue(packageInfo.active);
    }

    function testBuyPackageWithETHSuccess() public {
        uint256 packageId = _createTestPackage();
        
        uint256 validAfter = block.timestamp;
        uint256 validUntil = block.timestamp + 1 hours;
        bytes memory signature = _createSignature(packageId, validUntil, validAfter, operatorPrivateKey);

        uint256 userBalanceBefore = user.balance;
        uint256 contractBalanceBefore = address(packStore).balance;

        vm.prank(user);
        packStore.buyPackage{value: 1 ether}(packageId, validUntil, validAfter, signature);

        // Check balances
        assertEq(user.balance, userBalanceBefore - 1 ether);
        assertEq(address(packStore).balance, contractBalanceBefore + 1 ether);

        // Check package sold count
        PackSaleStore.PackageInfo memory packageInfo = packStore.getPackageInfo(packageId);
        assertEq(packageInfo.sold, 1);

        // Check user received assets
        assertEq(bicToken.balanceOf(user), 1000 * 10**18 + 100 * 10**18);
        assertEq(erc721.ownerOf(1), user);
    }

    function testBuyPackageWithERC20Success() public {
        uint256 packageId = _createTestPackageWithERC20Payment();
        
        uint256 validAfter = block.timestamp;
        uint256 validUntil = block.timestamp + 1 hours;
        bytes memory signature = _createSignature(packageId, validUntil, validAfter, operatorPrivateKey);

        uint256 userBalanceBefore = bicToken.balanceOf(user);
        uint256 contractBalanceBefore = bicToken.balanceOf(address(packStore));

        vm.prank(user);
        packStore.buyPackage(packageId, validUntil, validAfter, signature);

        // Check balances
        assertEq(bicToken.balanceOf(user), userBalanceBefore - 50 * 10**18);
        assertEq(bicToken.balanceOf(address(packStore)), contractBalanceBefore + 50 * 10**18);

        // Check package sold count
        PackSaleStore.PackageInfo memory packageInfo = packStore.getPackageInfo(packageId);
        assertEq(packageInfo.sold, 1);
    }

    function testBuyPackageRevertsWithInvalidPackageId() public {
        uint256 invalidPackageId = 999;
        uint256 validAfter = block.timestamp;
        uint256 validUntil = block.timestamp + 1 hours;
        bytes memory signature = _createSignature(invalidPackageId, validUntil, validAfter, operatorPrivateKey);

        vm.prank(user);
        vm.expectRevert(PackSaleStore.InvalidPackageId.selector);
        packStore.buyPackage{value: 1 ether}(invalidPackageId, validUntil, validAfter, signature);
    }

    function testBuyPackageRevertsWhenInactive() public {
        uint256 packageId = _createTestPackage();
        
        // Deactivate package
        vm.prank(owner);
        packStore.deactivatePackage(packageId);

        uint256 validAfter = block.timestamp;
        uint256 validUntil = block.timestamp + 1 hours;
        bytes memory signature = _createSignature(packageId, validUntil, validAfter, operatorPrivateKey);

        vm.prank(user);
        vm.expectRevert(PackSaleStore.PackageNotActive.selector);
        packStore.buyPackage{value: 1 ether}(packageId, validUntil, validAfter, signature);
    }

    function testBuyPackageRevertsWhenSoldOut() public {
        // Create package with capacity 1
        packageAssets = new ITokenBundle.Token[](1);
        packageAssets[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 100 * 10**18
        });

        vm.prank(owner);
        uint256 packageId = packStore.registerPackage(1, packageAssets, 1 ether, address(0));

        // Buy the only package
        uint256 validAfter = block.timestamp;
        uint256 validUntil = block.timestamp + 1 hours;
        bytes memory signature = _createSignature(packageId, validUntil, validAfter, operatorPrivateKey);

        vm.prank(user);
        packStore.buyPackage{value: 1 ether}(packageId, validUntil, validAfter, signature);

        // Try to buy again - should fail
        signature = _createSignature(packageId, validUntil + 1, validAfter, operatorPrivateKey);
        
        vm.prank(user);
        vm.expectRevert(PackSaleStore.PackageSoldOut.selector);
        packStore.buyPackage{value: 1 ether}(packageId, validUntil + 1, validAfter, signature);
    }

    function testBuyPackageRevertsWithInvalidTimeWindow() public {
        uint256 packageId = _createTestPackage();
        
        // Test with validAfter > current time
        uint256 validAfter = block.timestamp + 1 hours;
        uint256 validUntil = block.timestamp + 2 hours;
        bytes memory signature = _createSignature(packageId, validUntil, validAfter, operatorPrivateKey);

        vm.prank(user);
        vm.expectRevert(PackSaleStore.InvalidTimeWindow.selector);
        packStore.buyPackage{value: 1 ether}(packageId, validUntil, validAfter, signature);

        // Test with validUntil < current time - skip warp to avoid underflow
        vm.warp(block.timestamp + 3 hours); // Move forward in time
        validAfter = block.timestamp - 2 hours;
        validUntil = block.timestamp - 1 hours;
        signature = _createSignature(packageId, validUntil, validAfter, operatorPrivateKey);

        vm.prank(user);
        vm.expectRevert(PackSaleStore.InvalidTimeWindow.selector);
        packStore.buyPackage{value: 1 ether}(packageId, validUntil, validAfter, signature);
    }

    function testBuyPackageRevertsWithUsedHash() public {
        uint256 packageId = _createTestPackage();
        
        uint256 validAfter = block.timestamp;
        uint256 validUntil = block.timestamp + 1 hours;
        bytes memory signature = _createSignature(packageId, validUntil, validAfter, operatorPrivateKey);

        // First purchase should succeed
        vm.prank(user);
        packStore.buyPackage{value: 1 ether}(packageId, validUntil, validAfter, signature);

        // Second purchase with same parameters should fail
        vm.prank(user);
        vm.expectRevert(PackSaleStore.HashAlreadyUsed.selector);
        packStore.buyPackage{value: 1 ether}(packageId, validUntil, validAfter, signature);
    }

    function testBuyPackageRevertsWithInvalidSignature() public {
        uint256 packageId = _createTestPackage();
        
        uint256 validAfter = block.timestamp;
        uint256 validUntil = block.timestamp + 1 hours;
        bytes memory invalidSignature = _createSignature(packageId, validUntil, validAfter, attackerPrivateKey);

        vm.prank(user);
        vm.expectRevert(PackSaleStore.InvalidSignature.selector);
        packStore.buyPackage{value: 1 ether}(packageId, validUntil, validAfter, invalidSignature);
    }

    function testBuyPackageRevertsWithInsufficientETH() public {
        uint256 packageId = _createTestPackage();
        
        uint256 validAfter = block.timestamp;
        uint256 validUntil = block.timestamp + 1 hours;
        bytes memory signature = _createSignature(packageId, validUntil, validAfter, operatorPrivateKey);

        vm.prank(user);
        vm.expectRevert(PackSaleStore.InsufficientPayment.selector);
        packStore.buyPackage{value: 0.5 ether}(packageId, validUntil, validAfter, signature);
    }

    function testBuyPackageRefundsExcessETH() public {
        uint256 packageId = _createTestPackage();
        
        uint256 validAfter = block.timestamp;
        uint256 validUntil = block.timestamp + 1 hours;
        bytes memory signature = _createSignature(packageId, validUntil, validAfter, operatorPrivateKey);

        uint256 userBalanceBefore = user.balance;
        uint256 excessAmount = 0.5 ether;

        vm.prank(user);
        packStore.buyPackage{value: 1 ether + excessAmount}(packageId, validUntil, validAfter, signature);

        // Should only charge 1 ether, refund the excess
        assertEq(user.balance, userBalanceBefore - 1 ether);
        assertEq(address(packStore).balance, 1 ether);
    }

    function testBuyPackageRevertsWithETHForERC20Payment() public {
        uint256 packageId = _createTestPackageWithERC20Payment();
        
        uint256 validAfter = block.timestamp;
        uint256 validUntil = block.timestamp + 1 hours;
        bytes memory signature = _createSignature(packageId, validUntil, validAfter, operatorPrivateKey);

        vm.prank(user);
        vm.expectRevert(PackSaleStore.InsufficientPayment.selector);
        packStore.buyPackage{value: 1 ether}(packageId, validUntil, validAfter, signature);
    }

    function testGetPackageAssets() public {
        uint256 packageId = _createTestPackage();
        
        ITokenBundle.Token[] memory assets = packStore.getPackageAssets(packageId);
        
        assertEq(assets.length, 2);
        assertEq(assets[0].assetContract, address(bicToken));
        assertEq(assets[0].totalAmount, 100 * 10**18);
        assertEq(assets[1].assetContract, address(erc721));
        assertEq(assets[1].tokenId, 1);
    }

    function testIsHashUsed() public {
        uint256 packageId = _createTestPackage();
        
        uint256 validAfter = block.timestamp;
        uint256 validUntil = block.timestamp + 1 hours;
        
        // Hash should not be used initially
        assertFalse(packStore.isHashUsed(packageId, validUntil, validAfter));
        
        bytes memory signature = _createSignature(packageId, validUntil, validAfter, operatorPrivateKey);
        
        vm.prank(user);
        packStore.buyPackage{value: 1 ether}(packageId, validUntil, validAfter, signature);
        
        // Hash should be used after purchase
        assertTrue(packStore.isHashUsed(packageId, validUntil, validAfter));
    }

    function testGenerateHash() public {
        uint256 packageId = 1;
        uint256 validUntil = block.timestamp + 1 hours;
        uint256 validAfter = block.timestamp;
        
        bytes32 expectedHash = keccak256(abi.encodePacked(packageId, validUntil, validAfter));
        bytes32 actualHash = packStore.generateHash(packageId, validUntil, validAfter);
        
        assertEq(actualHash, expectedHash);
    }

    function testWithdrawETH() public {
        uint256 packageId = _createTestPackage();
        
        // Buy package to add ETH to contract
        uint256 validAfter = block.timestamp;
        uint256 validUntil = block.timestamp + 1 hours;
        bytes memory signature = _createSignature(packageId, validUntil, validAfter, operatorPrivateKey);

        vm.prank(user);
        packStore.buyPackage{value: 1 ether}(packageId, validUntil, validAfter, signature);

        address payable recipient = payable(address(0x9999));
        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(owner);
        packStore.withdrawETH(recipient, 0.5 ether);

        assertEq(recipient.balance, recipientBalanceBefore + 0.5 ether);
        assertEq(address(packStore).balance, 0.5 ether);
    }

    function testWithdrawETHAll() public {
        uint256 packageId = _createTestPackage();
        
        // Buy package to add ETH to contract
        uint256 validAfter = block.timestamp;
        uint256 validUntil = block.timestamp + 1 hours;
        bytes memory signature = _createSignature(packageId, validUntil, validAfter, operatorPrivateKey);

        vm.prank(user);
        packStore.buyPackage{value: 1 ether}(packageId, validUntil, validAfter, signature);

        address payable recipient = payable(address(0x9999));
        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(owner);
        packStore.withdrawETH(recipient, 0); // 0 means withdraw all

        assertEq(recipient.balance, recipientBalanceBefore + 1 ether);
        assertEq(address(packStore).balance, 0);
    }

    function testWithdrawToken() public {
        uint256 packageId = _createTestPackageWithERC20Payment();
        
        // Buy package to add tokens to contract
        uint256 validAfter = block.timestamp;
        uint256 validUntil = block.timestamp + 1 hours;
        bytes memory signature = _createSignature(packageId, validUntil, validAfter, operatorPrivateKey);

        vm.prank(user);
        packStore.buyPackage(packageId, validUntil, validAfter, signature);

        address recipient = address(0x9999);
        uint256 recipientBalanceBefore = bicToken.balanceOf(recipient);

        vm.prank(owner);
        packStore.withdrawToken(address(bicToken), recipient, 25 * 10**18);

        assertEq(bicToken.balanceOf(recipient), recipientBalanceBefore + 25 * 10**18);
        assertEq(bicToken.balanceOf(address(packStore)), 25 * 10**18);
    }

    function testEmergencyReleaseAssets() public {
        uint256 packageId = _createTestPackage();
        
        address recipient = address(0x9999);
        
        vm.prank(owner);
        packStore.emergencyReleaseAssets(packageId, recipient);
        
        // Check assets were transferred to recipient
        assertEq(bicToken.balanceOf(recipient), 100 * 10**18);
        assertEq(erc721.ownerOf(1), recipient);
    }

    // Helper functions

    function _createTestPackage() internal returns (uint256 packageId) {
        packageAssets = new ITokenBundle.Token[](2);
        packageAssets[0] = ITokenBundle.Token({
            assetContract: address(bicToken),
            tokenType: ITokenBundle.TokenType.ERC20,
            tokenId: 0,
            totalAmount: 100 * 10**18
        });
        packageAssets[1] = ITokenBundle.Token({
            assetContract: address(erc721),
            tokenType: ITokenBundle.TokenType.ERC721,
            tokenId: 1,
            totalAmount: 1
        });

        vm.prank(owner);
        packageId = packStore.registerPackage(10, packageAssets, 1 ether, address(0));
    }

    function _createTestPackageWithERC20Payment() internal returns (uint256 packageId) {
        packageAssets = new ITokenBundle.Token[](1);
        packageAssets[0] = ITokenBundle.Token({
            assetContract: address(erc1155),
            tokenType: ITokenBundle.TokenType.ERC1155,
            tokenId: 1,
            totalAmount: 50
        });

        vm.prank(owner);
        packageId = packStore.registerPackage(5, packageAssets, 50 * 10**18, address(bicToken));
    }

    function _createSignature(
        uint256 packageId,
        uint256 validUntil,
        uint256 validAfter,
        uint256 privateKey
    ) internal pure returns (bytes memory) {
        bytes32 hash = keccak256(abi.encodePacked(packageId, validUntil, validAfter));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }
}
