# MiniGamePoolReward Contract

## Overview

The `MiniGamePoolReward` contract is designed for distributing ERC20, ERC721, and ERC1155 tokens to users using merkle trees with time-based claim periods. This allows for efficient, gas-optimized distribution of rewards to large numbers of users while providing strong security guarantees.

## Features

- **Multi-Token Support**: Distribute ERC20, ERC721, and ERC1155 tokens as rewards
- **Merkle Tree Verification**: Use merkle proofs to verify user eligibility
- **Time-Based Claims**: Set expiration times for each merkle root
- **Claim Tracking**: Prevent double-claiming from the same merkle root
- **Owner Controls**: Admin functions for managing roots and withdrawing tokens
- **Emergency Functions**: Emergency withdrawal capabilities
- **Token Receiver Support**: Implements ERC721Receiver and ERC1155Receiver interfaces

## Core Components

### Constructor
```solidity
constructor(address _owner)
```
- `_owner`: The owner/admin of the contract

### Key Functions

#### Adding Merkle Roots (Owner Only)
```solidity
function addMerkleRoot(bytes32 _merkleRoot, uint256 _endTime) external onlyOwner
```
- Adds a new merkle root with an expiration time
- Can update existing roots with new end times

#### Claiming ERC20 Tokens
```solidity
function claimERC20Tokens(
    bytes32 _merkleRoot,
    address _token,
    uint256 _amount,
    bytes32[] calldata _merkleProof
) external nonReentrant
```
- Users provide merkle proof to claim their allocated ERC20 tokens
- Validates proof against the merkle root
- Prevents double-claiming and expired claims

#### Claiming ERC721 Tokens
```solidity
function claimERC721Tokens(
    bytes32 _merkleRoot,
    address _token,
    uint256 _tokenId,
    bytes32[] calldata _merkleProof
) external nonReentrant
```
- Users provide merkle proof to claim their allocated ERC721 tokens
- Validates proof against the merkle root
- Prevents double-claiming and expired claims

#### Claiming ERC1155 Tokens
```solidity
function claimERC1155Tokens(
    bytes32 _merkleRoot,
    address _token,
    uint256 _tokenId,
    uint256 _amount,
    bytes32[] calldata _merkleProof
) external nonReentrant
```
- Users provide merkle proof to claim their allocated ERC1155 tokens
- Validates proof against the merkle root
- Prevents double-claiming and expired claims

#### Utility Functions
- `hasClaimedFromRoot(bytes32, address)`: Check if address has claimed
- `getMerkleRootInfo(bytes32)`: Get root information
- `getAllMerkleRoots()`: Get all merkle roots
- `isRootActive(bytes32)`: Check if root is still active
- `getERC20Balance(address)`: Get current ERC20 token balance
- `getERC1155Balance(address, uint256)`: Get current ERC1155 token balance

#### Admin Functions
- `withdrawERC20Tokens(address, address, uint256)`: Withdraw specific ERC20 amount
- `withdrawERC721Tokens(address, address, uint256)`: Withdraw specific ERC721 token
- `withdrawERC1155Tokens(address, address, uint256, uint256)`: Withdraw specific ERC1155 amount
- `emergencyWithdrawERC20(address, address)`: Withdraw all ERC20 tokens

## Usage Example

### 1. Deploy Contract
```solidity
MiniGamePoolReward reward = new MiniGamePoolReward(ownerAddress);
```

### 2. Fund Contract
Transfer tokens to the contract address for distribution.

### 3. Create Merkle Tree Off-Chain
```javascript
// Example user data for ERC20
const erc20Users = [
    { address: "0x123...", token: "0x456...", amount: "100000000000000000000", tokenId: 0 }, // 100 tokens
    { address: "0x789...", token: "0x456...", amount: "200000000000000000000", tokenId: 0 }  // 200 tokens
];

// Example user data for ERC721
const erc721Users = [
    { address: "0x123...", token: "0x789...", amount: 1, tokenId: 1 },
    { address: "0x456...", token: "0x789...", amount: 1, tokenId: 2 }
];

// Example user data for ERC1155
const erc1155Users = [
    { address: "0x123...", token: "0xabc...", amount: 50, tokenId: 1 },
    { address: "0x456...", token: "0xabc...", amount: 100, tokenId: 2 }
];

// Create leaves (hash of address + token + amount + tokenId)
const erc20Leaves = erc20Users.map(user => 
    keccak256(solidityPack(["address", "address", "uint256", "uint256"], [user.address, user.token, user.amount, user.tokenId]))
);

const erc721Leaves = erc721Users.map(user => 
    keccak256(solidityPack(["address", "address", "uint256", "uint256"], [user.address, user.token, user.amount, user.tokenId]))
);

const erc1155Leaves = erc1155Users.map(user => 
    keccak256(solidityPack(["address", "address", "uint256", "uint256"], [user.address, user.token, user.amount, user.tokenId]))
);

// Build merkle trees and get roots
const erc20Tree = new MerkleTree(erc20Leaves, keccak256, { sort: true });
const erc721Tree = new MerkleTree(erc721Leaves, keccak256, { sort: true });
const erc1155Tree = new MerkleTree(erc1155Leaves, keccak256, { sort: true });

const erc20Root = erc20Tree.getHexRoot();
const erc721Root = erc721Tree.getHexRoot();
const erc1155Root = erc1155Tree.getHexRoot();
```

### 4. Add Merkle Roots
```solidity
// Set claim period (e.g., 30 days from now)
uint256 endTime = block.timestamp + 30 days;

// Add the merkle roots
reward.addMerkleRoot(erc20Root, endTime);
reward.addMerkleRoot(erc721Root, endTime);
reward.addMerkleRoot(erc1155Root, endTime);
```

### 5. Users Claim Tokens
```solidity
// Generate proof off-chain for specific user
const erc20Proof = erc20Tree.getHexProof(erc20Leaf);
const erc721Proof = erc721Tree.getHexProof(erc721Leaf);
const erc1155Proof = erc1155Tree.getHexProof(erc1155Leaf);

// User claims tokens
reward.claimERC20Tokens(erc20Root, tokenAddress, amount, erc20Proof);
reward.claimERC721Tokens(erc721Root, tokenAddress, tokenId, erc721Proof);
reward.claimERC1155Tokens(erc1155Root, tokenAddress, tokenId, amount, erc1155Proof);
```

## Merkle Tree Structure

The merkle tree leaves are constructed differently for each token type:

### ERC20 Tokens
```solidity
keccak256(abi.encodePacked(userAddress, tokenAddress, amount, 0))
```
- `userAddress`: The user's address
- `tokenAddress`: The ERC20 token contract address
- `amount`: The amount to claim
- `0`: Token ID (always 0 for ERC20)

### ERC721 Tokens
```solidity
keccak256(abi.encodePacked(userAddress, tokenAddress, 1, tokenId))
```
- `userAddress`: The user's address
- `tokenAddress`: The ERC721 token contract address
- `1`: Amount (always 1 for ERC721)
- `tokenId`: The specific token ID to claim

### ERC1155 Tokens
```solidity
keccak256(abi.encodePacked(userAddress, tokenAddress, amount, tokenId))
```
- `userAddress`: The user's address
- `tokenAddress`: The ERC1155 token contract address
- `amount`: The amount to claim
- `tokenId`: The specific token ID to claim

## Security Features

### Access Control
- Only owner can add merkle roots
- Only owner can withdraw tokens
- Users can only claim with valid proofs

### Reentrancy Protection
- `nonReentrant` modifier on claim functions
- Uses OpenZeppelin's ReentrancyGuard

### Double-Claim Prevention
- Tracks claimed status per (merkleRoot, user) pair
- Prevents multiple claims from same root

### Time-Based Expiration
- Claims expire after specified end time
- Prevents indefinite claim periods

### Token Receiver Support
- Implements ERC721Receiver interface
- Implements ERC1155Receiver interface
- Allows safe token transfers to the contract

## Error Handling

The contract includes comprehensive error handling:

- `InvalidMerkleRoot()`: Zero merkle root provided
- `InvalidEndTime()`: End time in the past
- `AlreadyClaimed()`: User already claimed from this root
- `InvalidProof()`: Merkle proof verification failed
- `ClaimPeriodExpired()`: Claim period has ended
- `InsufficientBalance()`: Contract lacks sufficient tokens
- `ZeroAmount()`: Zero amount specified
- `ZeroAddress()`: Zero address provided
- `RootNotFound()`: Merkle root doesn't exist

## Best Practices

### For Administrators
1. **Test Merkle Trees**: Always verify merkle tree construction off-chain
2. **Reasonable End Times**: Set appropriate claim periods (not too short/long)
3. **Fund Contract**: Ensure contract has sufficient tokens before adding roots
4. **Monitor Claims**: Track claim activity and remaining balances
5. **Token Compatibility**: Ensure tokens support the required interfaces

### For Users
1. **Claim Early**: Don't wait until the last minute to claim
2. **Verify Proofs**: Ensure merkle proofs are generated correctly
3. **Check Eligibility**: Verify you're included in the merkle tree
4. **One Claim Per Root**: Remember you can only claim once per merkle root
5. **Token Type**: Use the correct claim function for your token type

## Gas Optimization

- Uses merkle trees for O(log n) verification instead of storing all user data
- Minimal storage per user (just claimed status)
- Efficient proof verification using OpenZeppelin's MerkleProof library
- Single transaction per claim
- Separate functions for different token types to optimize gas usage

## Integration Notes

### With Frontend
- Generate merkle trees server-side or in secure environment
- Provide users with their proofs via API
- Cache proofs for better UX
- Show claim status and remaining time
- Display appropriate claim function based on token type

### With Other Contracts
- Can be integrated with gaming contracts
- Supports any ERC20, ERC721, or ERC1155 token
- Events emitted for tracking
- View functions for status queries
- Safe token transfer support

## Testing

The contract includes comprehensive test coverage:
- Unit tests for all functions
- Edge case testing for each token type
- Fuzz testing for robustness
- Integration test scenarios
- Gas usage optimization tests
- Mock contracts for testing

See `test/distribute/MiniGamePoolReward.t.sol` for complete test suite. 