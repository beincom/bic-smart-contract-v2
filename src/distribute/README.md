# MiniGamePoolReward Contract

## Overview

The `MiniGamePoolReward` contract is designed for distributing ERC20 tokens to users using merkle trees with time-based claim periods. This allows for efficient, gas-optimized distribution of rewards to large numbers of users while providing strong security guarantees.

## Features

- **ERC20 Token Distribution**: Distribute any ERC20 token as rewards
- **Merkle Tree Verification**: Use merkle proofs to verify user eligibility
- **Time-Based Claims**: Set expiration times for each merkle root
- **Claim Tracking**: Prevent double-claiming from the same merkle root
- **Owner Controls**: Admin functions for managing roots and withdrawing tokens
- **Emergency Functions**: Emergency withdrawal capabilities

## Core Components

### Constructor
```solidity
constructor(IERC20 _rewardToken, address _owner)
```
- `_rewardToken`: The ERC20 token to be distributed
- `_owner`: The owner/admin of the contract

### Key Functions

#### Adding Merkle Roots (Owner Only)
```solidity
function addMerkleRoot(bytes32 _merkleRoot, uint256 _endTime) external onlyOwner
```
- Adds a new merkle root with an expiration time
- Can update existing roots with new end times

#### Claiming Tokens
```solidity
function claimTokens(
    bytes32 _merkleRoot,
    uint256 _amount,
    bytes32[] calldata _merkleProof
) external nonReentrant
```
- Users provide merkle proof to claim their allocated tokens
- Validates proof against the merkle root
- Prevents double-claiming and expired claims

#### Utility Functions
- `hasClaimedFromRoot(bytes32, address)`: Check if address has claimed
- `getMerkleRootInfo(bytes32)`: Get root information
- `getAllMerkleRoots()`: Get all merkle roots
- `isRootActive(bytes32)`: Check if root is still active
- `getContractBalance()`: Get current token balance

#### Admin Functions
- `withdrawTokens(address, uint256)`: Withdraw specific amount
- `emergencyWithdraw(address)`: Withdraw all tokens

## Usage Example

### 1. Deploy Contract
```solidity
MiniGamePoolReward reward = new MiniGamePoolReward(
    IERC20(tokenAddress),
    ownerAddress
);
```

### 2. Fund Contract
Transfer tokens to the contract address for distribution.

### 3. Create Merkle Tree Off-Chain
```javascript
// Example user data
const users = [
    { address: "0x123...", amount: "100000000000000000000" }, // 100 tokens
    { address: "0x456...", amount: "200000000000000000000" }, // 200 tokens
    { address: "0x789...", amount: "300000000000000000000" }  // 300 tokens
];

// Create leaves (hash of address + amount)
const leaves = users.map(user => 
    keccak256(solidityPack(["address", "uint256"], [user.address, user.amount]))
);

// Build merkle tree and get root
const tree = new MerkleTree(leaves, keccak256, { sort: true });
const root = tree.getHexRoot();
```

### 4. Add Merkle Root
```solidity
// Set claim period (e.g., 30 days from now)
uint256 endTime = block.timestamp + 30 days;

// Add the merkle root
reward.addMerkleRoot(root, endTime);
```

### 5. Users Claim Tokens
```solidity
// Generate proof off-chain for specific user
const proof = tree.getHexProof(leaf);

// User claims tokens
reward.claimTokens(root, amount, proof);
```

## Security Features

### Access Control
- Only owner can add merkle roots
- Only owner can withdraw tokens
- Users can only claim with valid proofs

### Reentrancy Protection
- `nonReentrant` modifier on claim function
- Uses OpenZeppelin's ReentrancyGuard

### Double-Claim Prevention
- Tracks claimed status per (merkleRoot, user) pair
- Prevents multiple claims from same root

### Time-Based Expiration
- Claims expire after specified end time
- Prevents indefinite claim periods

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

### For Users
1. **Claim Early**: Don't wait until the last minute to claim
2. **Verify Proofs**: Ensure merkle proofs are generated correctly
3. **Check Eligibility**: Verify you're included in the merkle tree
4. **One Claim Per Root**: Remember you can only claim once per merkle root

## Gas Optimization

- Uses merkle trees for O(log n) verification instead of storing all user data
- Minimal storage per user (just claimed status)
- Efficient proof verification using OpenZeppelin's MerkleProof library
- Single transaction per claim

## Integration Notes

### With Frontend
- Generate merkle trees server-side or in secure environment
- Provide users with their proofs via API
- Cache proofs for better UX
- Show claim status and remaining time

### With Other Contracts
- Can be integrated with gaming contracts
- Supports any ERC20 token
- Events emitted for tracking
- View functions for status queries

## Testing

The contract includes comprehensive test coverage:
- Unit tests for all functions
- Edge case testing
- Fuzz testing for robustness
- Integration test scenarios
- Gas usage optimization tests

See `test/distribute/MiniGamePoolReward.t.sol` for complete test suite. 