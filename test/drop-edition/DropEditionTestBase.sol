// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {DropErc1155} from "../../src/drop-edition/DropErc1155.sol";
// import {BicDropEdition} from "../../src/drop-edition/BicDropEdition.sol";
import {IDropErc1155} from "../../src/interfaces/IDropErc1155.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1e27); // 1 billion tokens with 18 decimals
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DropEditionTestBase is Test {
    // Contracts
    DropErc1155 public dropErc1155;
    MockERC20 public bicToken;
    MockERC20 public usdcToken;

    // Test addresses
    address public owner;
    address public primarySaleRecipient;
    address public platformFeeRecipient;
    address public user1;
    address public user2;
    address public user3;

    // Test constants
    string constant BASE_URI = "https://api.example.com/metadata/{id}.json";
    uint256 constant PLATFORM_FEE_BPS = 250; // 2.5%
    uint256 constant TOKEN_ID = 1;
    uint256 constant PHASE_ID = 0;

    // Collection metadata
    // BicDropEdition.CollectionMetadata public testMetadata;

    // Events for testing
    event ClaimPhaseUpdated(uint256 indexed tokenId, uint256 indexed phaseId, IDropErc1155.ClaimPhase phase);
    event TokensClaimed(
        address indexed claimer,
        address indexed receiver,
        uint256 indexed tokenId,
        uint256 phaseId,
        uint256 quantity
    );
    event MaxTotalSupplyUpdated(uint256 indexed tokenId, uint256 maxTotalSupply);
    event DefaultRoyaltyUpdated(address indexed royaltyRecipient, uint256 royaltyBps);
    event TokenURIUpdated(uint256 indexed tokenId, string uri);
    event TokensLazyMinted(uint256 indexed startTokenId, uint256 endTokenId, string[] baseURIs);

    function setUp() public virtual {
        // Set up test addresses
        owner = makeAddr("owner");
        primarySaleRecipient = makeAddr("primarySaleRecipient");
        platformFeeRecipient = makeAddr("platformFeeRecipient");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Deploy mock tokens
        bicToken = new MockERC20("BIC Token", "BIC");
        usdcToken = new MockERC20("USD Coin", "USDC");

        // Deploy contracts
        vm.startPrank(owner);
        
        dropErc1155 = new DropErc1155(BASE_URI, owner, primarySaleRecipient);

        vm.stopPrank();

        // Distribute tokens to test users
        _distributeTokens();
    }

    function _distributeTokens() internal {
        uint256 userAmount = 1000 * 1e18; // 1000 tokens each

        bicToken.transfer(user1, userAmount);
        bicToken.transfer(user2, userAmount);
        bicToken.transfer(user3, userAmount);

        usdcToken.transfer(user1, userAmount);
        usdcToken.transfer(user2, userAmount);
        usdcToken.transfer(user3, userAmount);

        // Deal ETH to users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
    }

    function _createBasicClaimPhase(
        uint256 tokenId,
        uint256 phaseId,
        uint256 pricePerToken,
        address currency
    ) internal returns (IDropErc1155.ClaimPhase memory) {
        IDropErc1155.ClaimPhase memory phase = IDropErc1155.ClaimPhase({
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + 7 days,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            pricePerToken: pricePerToken,
            currency: currency,
            merkleRoot: bytes32(0), // Public phase
            isActive: true
        });

        vm.prank(owner);
        dropErc1155.setClaimPhase(tokenId, phaseId, phase);

        return phase;
    }

    function _createBicClaimPhase(
        uint256 tokenId,
        uint256 phaseId,
        uint256 pricePerToken
    ) internal returns (IDropErc1155.ClaimPhase memory) {
        
        // Create a basic claim phase for testing
        IDropErc1155.ClaimPhase memory phase = IDropErc1155.ClaimPhase({
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + 7 days,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            pricePerToken: pricePerToken,
            currency: address(0),
            merkleRoot: bytes32(0),
            isActive: true
        });
        
        vm.prank(owner);
        dropErc1155.setClaimPhase(tokenId, phaseId, phase);
        
        return dropErc1155.getClaimPhase(tokenId, phaseId);
    }

    function _createMerkleProof(
        address[] memory addresses,
        uint256[] memory quantities,
        address targetAddress,
        uint256 targetQuantity
    ) internal pure returns (bytes32 merkleRoot, bytes32[] memory proof) {
        require(addresses.length == quantities.length, "Length mismatch");
        
        // Create leaves
        bytes32[] memory leaves = new bytes32[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(addresses[i], quantities[i]));
        }

        // Sort leaves (required for consistent merkle tree)
        _quickSort(leaves, int256(0), int256(leaves.length - 1));

        // Find target leaf
        bytes32 targetLeaf = keccak256(abi.encodePacked(targetAddress, targetQuantity));
        uint256 targetIndex = type(uint256).max;
        for (uint256 i = 0; i < leaves.length; i++) {
            if (leaves[i] == targetLeaf) {
                targetIndex = i;
                break;
            }
        }
        require(targetIndex != type(uint256).max, "Target not found in leaves");

        // Calculate merkle root and generate proof
        merkleRoot = _calculateMerkleRoot(leaves);
        proof = _generateMerkleProof(leaves, targetIndex);
    }

    function _quickSort(bytes32[] memory arr, int256 left, int256 right) internal pure {
        if (left >= right) return;
        
        int256 i = left;
        int256 j = right;
        bytes32 pivot = arr[uint256(left + (right - left) / 2)];
        
        while (i <= j) {
            while (arr[uint256(i)] < pivot) i++;
            while (pivot < arr[uint256(j)]) j--;
            if (i <= j) {
                (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
                i++;
                j--;
            }
        }
        
        if (left < j) _quickSort(arr, left, j);
        if (i < right) _quickSort(arr, i, right);
    }

    function _calculateMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        if (leaves.length == 0) return bytes32(0);
        if (leaves.length == 1) return leaves[0];

        while (leaves.length > 1) {
            bytes32[] memory nextLevel = new bytes32[]((leaves.length + 1) / 2);
            
            for (uint256 i = 0; i < leaves.length; i += 2) {
                if (i + 1 < leaves.length) {
                    nextLevel[i / 2] = _hashPair(leaves[i], leaves[i + 1]);
                } else {
                    nextLevel[i / 2] = leaves[i];
                }
            }
            
            leaves = nextLevel;
        }
        
        return leaves[0];
    }

    function _generateMerkleProof(bytes32[] memory leaves, uint256 index) internal pure returns (bytes32[] memory proof) {
        if (leaves.length <= 1) {
            return new bytes32[](0);
        }

        uint256 proofLength = 0;
        uint256 tempLength = leaves.length;
        while (tempLength > 1) {
            proofLength++;
            tempLength = (tempLength + 1) / 2;
        }

        proof = new bytes32[](proofLength);
        uint256 proofIndex = 0;
        uint256 currentIndex = index;

        bytes32[] memory currentLevel = leaves;

        while (currentLevel.length > 1) {
            if (currentIndex % 2 == 0) {
                // We're on the left, sibling is on the right
                if (currentIndex + 1 < currentLevel.length) {
                    proof[proofIndex] = currentLevel[currentIndex + 1];
                }
            } else {
                // We're on the right, sibling is on the left
                proof[proofIndex] = currentLevel[currentIndex - 1];
            }

            // Move to next level
            bytes32[] memory nextLevel = new bytes32[]((currentLevel.length + 1) / 2);
            for (uint256 i = 0; i < currentLevel.length; i += 2) {
                if (i + 1 < currentLevel.length) {
                    nextLevel[i / 2] = _hashPair(currentLevel[i], currentLevel[i + 1]);
                } else {
                    nextLevel[i / 2] = currentLevel[i];
                }
            }

            currentLevel = nextLevel;
            currentIndex = currentIndex / 2;
            proofIndex++;
        }
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _approveTokens(address user, address spender, uint256 amount) internal {
        vm.startPrank(user);
        bicToken.approve(spender, amount);
        usdcToken.approve(spender, amount);
        vm.stopPrank();
    }

    function _setMaxSupply(uint256 tokenId, uint256 maxSupply) internal {
        vm.prank(owner);
        dropErc1155.setMaxTotalSupply(tokenId, maxSupply);
    }

    function _setBicMaxSupply(uint256 tokenId, uint256 maxSupply) internal {
        vm.prank(owner);
        dropErc1155.setMaxTotalSupply(tokenId, maxSupply);
    }

    // Helper to skip time
    function _skipTime(uint256 timeToSkip) internal {
        vm.warp(block.timestamp + timeToSkip);
    }

    // Helper to create claim request
    function _createClaimRequest(
        address receiver,
        uint256 tokenId,
        uint256 quantity,
        uint256 pricePerToken,
        address currency,
        bytes32[] memory proofs
    ) internal pure returns (IDropErc1155.ClaimRequest memory) {
        return IDropErc1155.ClaimRequest({
            receiver: receiver,
            tokenId: tokenId,
            quantity: quantity,
            pricePerToken: pricePerToken,
            currency: currency,
            proofs: proofs
        });
    }
} 