// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {BicEdition} from "src/edition/BicEdition.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDrop1155} from "src/extension/interface/IDrop1155.sol";
import {IClaimCondition} from "src/extension/interface/IClaimCondition.sol";

contract MockERC20 is IERC20 {
    string public constant name = "MockToken";
    string public constant symbol = "MTK";
    uint8 public constant decimals = 18;
    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    function transfer(address to, uint256 amount) external override returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient");
        require(allowance[from][msg.sender] >= amount, "Not allowed");
        balanceOf[from] -= amount;
        allowance[from][msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}

contract BicEditionTest is Test {
    BicEdition public edition;
    address public owner = address(0xABCD);
    address public user = address(0xBEEF);
    address public recipient = address(0xCAFE);
    MockERC20 public erc20;

    function setUp() public {
        erc20 = new MockERC20();
        edition = new BicEdition("BicEdition","E-BIC","https://base.uri/", owner, recipient);
        vm.prank(owner);
        edition.setMaxTotalSupply(1, 100);
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function testOwnerCanSetPrimarySaleRecipient() public {
        vm.prank(owner);
        edition.setPrimarySaleRecipient(user);
        assertEq(edition.primarySaleRecipient(), user);
    }

    function testNonOwnerCannotSetPrimarySaleRecipient() public {
        vm.expectRevert();
        edition.setPrimarySaleRecipient(user);
    }

    function testOwnerCanSetMaxTotalSupply() public {
        vm.prank(owner);
        edition.setMaxTotalSupply(2, 50);
        assertEq(edition.maxTotalSupply(2), 50);
    }

    function testNonOwnerCannotSetMaxTotalSupply() public {
        vm.expectRevert();
        edition.setMaxTotalSupply(2, 50);
    }

    function testOwnerMintWithinMaxSupply() public {
        vm.prank(owner);
        edition.ownerMint(user, 1, 10);
        assertEq(edition.totalSupply(1), 10);
        assertEq(edition.balanceOf(user, 1), 10);
    }

    function testOwnerMintExceedsMaxSupplyReverts() public {
        vm.prank(owner);
        edition.ownerMint(user, 1, 100);
        vm.prank(owner);
        vm.expectRevert();
        edition.ownerMint(user, 1, 1);
    }

    function testOwnerMintBatchWithinMaxSupply() public {
        vm.prank(owner);
        edition.setMaxTotalSupply(2, 50);
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1; ids[1] = 2;
        amounts[0] = 10; amounts[1] = 20;
        vm.prank(owner);
        edition.ownerMintBatch(user, ids, amounts);
        assertEq(edition.totalSupply(1), 10);
        assertEq(edition.totalSupply(2), 20);
    }

    function testOwnerMintBatchExceedsMaxSupplyReverts() public {
        vm.prank(owner);
        edition.setMaxTotalSupply(2, 15);
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1; ids[1] = 2;
        amounts[0] = 10; amounts[1] = 20;
        vm.prank(owner);
        vm.expectRevert();
        edition.ownerMintBatch(user, ids, amounts);
    }

    function testSetCondtionAndClaim() public {
        vm.prank(owner);
        IClaimCondition.ClaimCondition[] memory conditions = new IClaimCondition.ClaimCondition[](1);
        conditions[0] = IClaimCondition.ClaimCondition({
            startTimestamp: block.timestamp,
            maxClaimableSupply: 100,
            supplyClaimed: 0,
            pricePerToken: 1000000000000000000,
            currency: address(erc20),
            merkleRoot: bytes32(0),
            quantityLimitPerWallet: 99,
            metadata: ""
        });
        edition.setClaimConditions(
            1,
            conditions,
            false
        );
        erc20.mint(user, 10000000000000000000);

        vm.startPrank(user);
        erc20.approve(address(edition), 1000000000000000000);
        edition.claim(user, 1, 1, address(erc20), 1000000000000000000, IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 1,
            pricePerToken: 1000000000000000000,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        assertEq(edition.balanceOf(user, 1), 1);
        assertEq(erc20.balanceOf(user), 9000000000000000000);
    }

    function testLazyMint() public {
        vm.startPrank(owner);
        edition.lazyMint(1, "https://example.com/lazy/metadata/1", "0x");
        assertEq(edition.tokenURI(0), "https://example.com/lazy/metadata/1");
        edition.lazyMint(2, "https://example.com/lazy/metadata/1", "0x");
        vm.stopPrank();
        assertEq(edition.tokenURI(1), "https://example.com/lazy/metadata/1");
        assertEq(edition.totalSupply(1), 0); // No tokens minted yet
        assertEq(edition.tokenURI(2), "https://example.com/lazy/metadata/1");
        assertEq(edition.totalSupply(2), 0); // No tokens minted yet

        // if not lazy mint then get uri https://base.uri/{TokenId}
        assertEq(edition.uri(5), "https://base.uri/5");
    }

    function testClaimReachesMaxClaimableSupply() public {
        // Set claim condition with maxClaimableSupply = 5
        vm.prank(owner);
        IClaimCondition.ClaimCondition[] memory conditions = new IClaimCondition.ClaimCondition[](1);
        conditions[0] = IClaimCondition.ClaimCondition({
            startTimestamp: block.timestamp,
            maxClaimableSupply: 5,
            supplyClaimed: 0,
            pricePerToken: 1000000000000000000,
            currency: address(erc20),
            merkleRoot: bytes32(0),
            quantityLimitPerWallet: 10,
            metadata: ""
        });
        edition.setClaimConditions(1, conditions, false);

        // Mint tokens to users
        erc20.mint(user, 10000000000000000000);
        erc20.mint(recipient, 10000000000000000000);

        // First user claims 3 tokens
        vm.startPrank(user);
        erc20.approve(address(edition), 3000000000000000000);
        edition.claim(user, 1, 3, address(erc20), 1000000000000000000, IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 10,
            pricePerToken: 1000000000000000000,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        // Second user claims 2 tokens (reaches maxClaimableSupply)
        vm.startPrank(recipient);
        erc20.approve(address(edition), 2000000000000000000);
        edition.claim(recipient, 1, 2, address(erc20), 1000000000000000000, IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 10,
            pricePerToken: 1000000000000000000,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        // Third user tries to claim 1 token but should revert due to maxClaimableSupply
        address thirdUser = address(0x1234);
        erc20.mint(thirdUser, 1000000000000000000);
        vm.startPrank(thirdUser);
        erc20.approve(address(edition), 1000000000000000000);
        vm.expectRevert();
        edition.claim(thirdUser, 1, 1, address(erc20), 1000000000000000000, IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 10,
            pricePerToken: 1000000000000000000,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        assertEq(edition.totalSupply(1), 5);
        assertEq(edition.balanceOf(user, 1), 3);
        assertEq(edition.balanceOf(recipient, 1), 2);
    }

    function testClaimReachesQuantityLimitPerWallet() public {
        // Set claim condition with quantityLimitPerWallet = 3
        vm.prank(owner);
        IClaimCondition.ClaimCondition[] memory conditions = new IClaimCondition.ClaimCondition[](1);
        conditions[0] = IClaimCondition.ClaimCondition({
            startTimestamp: block.timestamp,
            maxClaimableSupply: 100,
            supplyClaimed: 0,
            pricePerToken: 1000000000000000000,
            currency: address(erc20),
            merkleRoot: bytes32(0),
            quantityLimitPerWallet: 3,
            metadata: ""
        });
        edition.setClaimConditions(1, conditions, false);

        // Mint tokens to user
        erc20.mint(user, 10000000000000000000);

        // User claims 3 tokens (reaches quantityLimitPerWallet)
        vm.startPrank(user);
        erc20.approve(address(edition), 3000000000000000000);
        edition.claim(user, 1, 3, address(erc20), 1000000000000000000, IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 3,
            pricePerToken: 1000000000000000000,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        // User tries to claim 1 more token but should revert due to quantityLimitPerWallet
        vm.startPrank(user);
        erc20.approve(address(edition), 1000000000000000000);
        vm.expectRevert();
        edition.claim(user, 1, 1, address(erc20), 1000000000000000000, IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 3,
            pricePerToken: 1000000000000000000,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        assertEq(edition.totalSupply(1), 3);
        assertEq(edition.balanceOf(user, 1), 3);
    }

    function testClaimUserNotEnoughERC20() public {
        // Set claim condition
        vm.prank(owner);
        IClaimCondition.ClaimCondition[] memory conditions = new IClaimCondition.ClaimCondition[](1);
        conditions[0] = IClaimCondition.ClaimCondition({
            startTimestamp: block.timestamp,
            maxClaimableSupply: 100,
            supplyClaimed: 0,
            pricePerToken: 1000000000000000000,
            currency: address(erc20),
            merkleRoot: bytes32(0),
            quantityLimitPerWallet: 10,
            metadata: ""
        });
        edition.setClaimConditions(1, conditions, false);

        // Mint only 0.5 tokens worth to user (not enough for 1 token)
        erc20.mint(user, 500000000000000000);

        // User tries to claim 1 token but should revert due to insufficient ERC20
        vm.startPrank(user);
        erc20.approve(address(edition), 1000000000000000000);
        vm.expectRevert();
        edition.claim(user, 1, 1, address(erc20), 1000000000000000000, IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 10,
            pricePerToken: 1000000000000000000,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        assertEq(edition.totalSupply(1), 0);
        assertEq(edition.balanceOf(user, 1), 0);
    }

    function testClaimWithWhitelistProof() public {
        // Create a merkle tree with specific parameters for the user
        // The leaf must match exactly: keccak256(abi.encodePacked(user, quantityLimitPerWallet, pricePerToken, currency))
        bytes32 userLeaf = keccak256(abi.encodePacked(user, uint256(5), uint256(1000000000000000000), address(erc20)));
        bytes32 merkleRoot = userLeaf; // For single leaf, root = leaf

        // Set claim condition with merkle root (whitelist enabled) and very restrictive limits
        vm.prank(owner);
        IClaimCondition.ClaimCondition[] memory conditions = new IClaimCondition.ClaimCondition[](1);
        conditions[0] = IClaimCondition.ClaimCondition({
            startTimestamp: block.timestamp,
            maxClaimableSupply: 100,
            supplyClaimed: 0,
            pricePerToken: 1000000000000000000,
            currency: address(erc20),
            merkleRoot: merkleRoot,
            quantityLimitPerWallet: 1, // Very restrictive - only 1 token per wallet
            metadata: ""
        });
        edition.setClaimConditions(1, conditions, false);

        // Mint tokens to user
        erc20.mint(user, 10000000000000000000);

        // User claims with valid proof (matching the leaf exactly)
        vm.startPrank(user);
        erc20.approve(address(edition), 1000000000000000000);
        edition.claim(user, 1, 1, address(erc20), 1000000000000000000, IDrop1155.AllowlistProof({
            proof: new bytes32[](0), // Empty proof for single leaf
            quantityLimitPerWallet: 5, // This matches the leaf hash
            pricePerToken: 1000000000000000000,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        assertEq(edition.totalSupply(1), 1);
        assertEq(edition.balanceOf(user, 1), 1);
    }

    function testClaimWithOpenClaimLimit() public {
        // Set claim condition without merkle root (open claim)
        vm.prank(owner);
        IClaimCondition.ClaimCondition[] memory conditions = new IClaimCondition.ClaimCondition[](1);
        conditions[0] = IClaimCondition.ClaimCondition({
            startTimestamp: block.timestamp,
            maxClaimableSupply: 100,
            supplyClaimed: 0,
            pricePerToken: 1000000000000000000,
            currency: address(erc20),
            merkleRoot: bytes32(0), // No merkle root - open claim
            quantityLimitPerWallet: 5,
            metadata: ""
        });
        edition.setClaimConditions(1, conditions, false);

        // Mint tokens to user
        erc20.mint(user, 10*10000000000000000000);

        // User can claim through open claim limit
        vm.startPrank(user);
        erc20.approve(address(edition), 10*1000000000000000000);
        edition.claim(user, 1, 5, address(erc20), 1000000000000000000, IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 5,
            pricePerToken: 1000000000000000000,
            currency: address(erc20)
        }), "");

        assertEq(edition.totalSupply(1), 5);
        assertEq(edition.balanceOf(user, 1), 5);

        // User tries to claim 1 more token but should revert due to quantityLimitPerWallet
        vm.startPrank(user);
        erc20.approve(address(edition), 1000000000000000000);
        vm.expectRevert();
        edition.claim(user, 1, 1, address(erc20), 1000000000000000000, IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 5,
            pricePerToken: 1000000000000000000, 
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        // After claim, the supply should be 5 and the balance of user should be 5
        assertEq(edition.totalSupply(1), 5);
        assertEq(edition.balanceOf(user, 1), 5);

    }

    function testClaimWithWhitelistOverride() public {
        // Create a merkle tree with specific parameters for the user
        bytes32 userLeaf = keccak256(abi.encodePacked(user, uint256(5), uint256(0), address(erc20)));
        bytes32 merkleRoot = userLeaf; // For single leaf, root = leaf

        // Set claim condition with merkle root (whitelist enabled) and very restrictive limits
        vm.prank(owner);
        IClaimCondition.ClaimCondition[] memory conditions = new IClaimCondition.ClaimCondition[](1);
        conditions[0] = IClaimCondition.ClaimCondition({
            startTimestamp: block.timestamp,
            maxClaimableSupply: 100,
            supplyClaimed: 0,
            pricePerToken: 1000000000000000000,
            currency: address(erc20),
            merkleRoot: merkleRoot,
            quantityLimitPerWallet: 1, // Very restrictive - only 1 token per wallet
            metadata: ""
        });
        edition.setClaimConditions(1, conditions, false);

        // Mint tokens to user
        erc20.mint(user, 10000000000000000000);

        // whitelist user can claim up to 5 tokens and pay 0
        vm.startPrank(user);
        edition.claim(user, 1, 5, address(erc20), 0, IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 5, // Different from the leaf hash, so merkle proof fails
            pricePerToken: 0,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        // Non-whitelisted user can claim only 1 token and pay 1 ether of ERC20
        address nonWhitelistedUser = address(0x5678);
        erc20.mint(nonWhitelistedUser, 10000000000000000000);
        vm.startPrank(nonWhitelistedUser);
        erc20.approve(address(edition), 1000000000000000000);
        edition.claim(nonWhitelistedUser, 1, 1, address(erc20), 1000000000000000000, IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 1, // This overrides the condition's limit of 1
            pricePerToken: 1000000000000000000,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        // Non-whitelisted user can not claim more than 1 token
        vm.startPrank(nonWhitelistedUser);
        erc20.approve(address(edition), 1000000000000000000);
        vm.expectRevert();
        edition.claim(nonWhitelistedUser, 1, 1, address(erc20), 1000000000000000000, IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 1, // This overrides the condition's limit of 1
            pricePerToken: 1000000000000000000,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        assertEq(edition.totalSupply(1), 6);
        assertEq(edition.balanceOf(user, 1), 5);
        assertEq(edition.balanceOf(nonWhitelistedUser, 1), 1);
        assertEq(erc20.balanceOf(user), 10000000000000000000 - 0); // Whitelisted user paid 0
    }

    function testWhitelistPreventsNonWhitelistedUser() public {
        // Create a merkle tree with only the user address (whitelisted)
        bytes32 userLeaf = keccak256(abi.encodePacked(user, uint256(300), uint256(0), address(erc20))); // 300 quantity limit, 0 price
        bytes32 merkleRoot = userLeaf; // For single leaf, root = leaf

        // In this test, the merkle tree has only one leaf (the whitelisted user).
        // The proof for a single-leaf tree is an empty array.
        bytes32[] memory proof = new bytes32[](0);

        // Set claim condition with merkle root (whitelist enabled) and restrictive limits
        vm.prank(owner);
        IClaimCondition.ClaimCondition[] memory conditions = new IClaimCondition.ClaimCondition[](1);
        conditions[0] = IClaimCondition.ClaimCondition({
            startTimestamp: block.timestamp,
            maxClaimableSupply: 100,
            supplyClaimed: 0,
            pricePerToken: 1000000000000000000,
            currency: address(erc20),
            merkleRoot: merkleRoot,
            quantityLimitPerWallet: 0, // no-one can claim except whitelisted user can be claimed for free with 300 quantity
            metadata: ""
        });
        edition.setClaimConditions(1, conditions, false);

        // Mint tokens to both users
        erc20.mint(user, 10000000000000000000);
        address nonWhitelistedUser = address(0x5678);
        erc20.mint(nonWhitelistedUser, 1000000000000000000);

        // Whitelisted user can claim with higher limit (5) due to valid merkle proof
        vm.startPrank(user);
        erc20.approve(address(edition), 1000000000000000000);
        edition.claim(user, 1, 1, address(erc20), 0, IDrop1155.AllowlistProof({
        // This is a valid proof for the whitelisted user only
            proof: proof,
            quantityLimitPerWallet: 300,
            pricePerToken: 0,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        // Non-whitelisted user tries to claim with same condition with whitelist but should fail
        // The whitelist prevents them from overriding the condition's values
        vm.startPrank(nonWhitelistedUser);
        erc20.approve(address(edition), 1000000000000000000);
        vm.expectRevert();
        edition.claim(nonWhitelistedUser, 1, 1, address(erc20), 0, IDrop1155.AllowlistProof({
            proof: proof,
            quantityLimitPerWallet: 0,
            pricePerToken: 1000000000000000000,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        // Non-whitelisted user tries to claim with public condition but should fail due to quantityLimitPerWallet is 0
        vm.startPrank(nonWhitelistedUser);
        erc20.approve(address(edition), 1000000000000000000);
        vm.expectRevert();
        edition.claim(nonWhitelistedUser, 1, 1, address(erc20), 1000000000000000000, IDrop1155.AllowlistProof({
            proof: proof,
            quantityLimitPerWallet: 300, // This overrides the condition's limit of 1
            pricePerToken: 0,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        assertEq(edition.totalSupply(1), 1);
        assertEq(edition.balanceOf(user, 1), 1);
        assertEq(edition.balanceOf(nonWhitelistedUser, 1), 0);
    }

    function testWhitelistMultiLeafOverride() public {
        // Create merkle tree with two leaves: owner and user
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(owner, uint256(300), uint256(0), address(erc20)));
        leaves[1] = keccak256(abi.encodePacked(user, uint256(300), uint256(0), address(erc20)));
        
        // Calculate merkle root and proofs
        bytes32 merkleRoot = _hashPair(leaves[0], leaves[1]);
        
        // For a 2-leaf tree, each leaf's proof is just the other leaf
        bytes32[] memory userProof = new bytes32[](1);
        userProof[0] = leaves[0]; // owner's leaf as proof for user
        
        // Set claim condition with calculated merkle root for whitelist
        vm.prank(owner);
        IClaimCondition.ClaimCondition[] memory conditions = new IClaimCondition.ClaimCondition[](1);
        conditions[0] = IClaimCondition.ClaimCondition({
            startTimestamp: block.timestamp,
            maxClaimableSupply: 100,
            supplyClaimed: 0,
            pricePerToken: 1000000000000000000,
            currency: address(erc20),
            merkleRoot: merkleRoot,
            quantityLimitPerWallet: 0,
            metadata: ""
        });
        edition.setClaimConditions(1, conditions, false);

        // User claims with calculated proof
        vm.startPrank(user);
        edition.claim(user, 1, 1, address(erc20), 0, IDrop1155.AllowlistProof({
            proof: userProof,
            quantityLimitPerWallet: 300,
            pricePerToken: 0,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        // Assert user received the token
        assertEq(edition.balanceOf(user, 1), 1);
    }
} 