# MiniGamePointShop Contract

## Overview

The `MiniGamePointShop` contract is a secure token distribution system that allows users to claim ETH, ERC20, ERC721, and ERC1155 tokens after submitting a request that gets signed by a verifier address. This contract implements signature-based verification to ensure only authorized claims are processed.

## Features

- **Multi-Token Support**: Supports ETH, ERC20, ERC721, and ERC1155 tokens
- **Signature Verification**: All claims must be signed by a designated verifier address
- **Replay Attack Protection**: Uses nonces to prevent duplicate claims
- **Deadline Enforcement**: Claims have expiration timestamps
- **Admin Controls**: Owner can withdraw tokens and update verifier address
- **Reentrancy Protection**: Secure against reentrancy attacks

## Contract Architecture

### Core Components

1. **ClaimRequest Structure**: Contains all necessary information for a token claim
2. **TokenType Enum**: Defines supported token types (ETH, ERC20, ERC721, ERC1155)
3. **Verifier System**: Centralized signature verification
4. **Nonce Management**: Prevents replay attacks
5. **Admin Functions**: Token withdrawal and configuration management

### Key Functions

#### Claim Functions
- `claimETH()` - Claim ETH tokens
- `claimERC20()` - Claim ERC20 tokens  
- `claimERC721()` - Claim ERC721 tokens
- `claimERC1155()` - Claim ERC1155 tokens

#### Admin Functions
- `updateVerifier()` - Update the verifier address
- `withdrawETH()` - Withdraw ETH from contract
- `withdrawERC20()` - Withdraw ERC20 tokens
- `withdrawERC721()` - Withdraw ERC721 tokens
- `withdrawERC1155()` - Withdraw ERC1155 tokens

#### Utility Functions
- `getClaimRequestHash()` - Generate hash for signature verification
- `supportsInterface()` - ERC165 interface support

## Usage Flow

### 1. Setup
1. Deploy the contract with an owner and verifier address
2. Fund the contract with tokens to be distributed
3. Verifier generates signatures for valid claim requests

### 2. Claim Process
1. User creates a `ClaimRequest` with their details
2. Verifier signs the request hash
3. User submits the request with signature to the appropriate claim function
4. Contract verifies signature and processes the claim
5. Tokens are transferred to the user

### 3. Request Structure
```solidity
struct ClaimRequest {
    address user;           // Address claiming tokens
    address token;          // Token contract address (0x0 for ETH)
    uint256 amount;         // Amount to claim
    uint256 tokenId;        // Token ID (for ERC721/ERC1155)
    uint256 nonce;          // Unique identifier to prevent replay
    uint256 deadline;       // Expiration timestamp
    TokenType tokenType;    // Type of token being claimed
}
```

## Security Features

### Signature Verification
- Uses ECDSA for signature verification
- Implements Ethereum signed message standard
- Only accepts signatures from the designated verifier

### Replay Protection
- Each nonce can only be used once
- Nonces are marked as used after successful claims
- Prevents duplicate claim attacks

### Access Control
- Owner-only functions for critical operations
- Verifier-only signature validation
- Reentrancy protection on all claim functions

### Input Validation
- Checks for zero addresses and amounts
- Validates token types match function calls
- Enforces deadline constraints

## Deployment

### Prerequisites
- Foundry/Forge installed
- Environment variables set:
  - `PRIVATE_KEY`: Deployer's private key
  - `VERIFIER_ADDRESS`: Address of the verifier

### Deploy Command
```bash
forge script script/distribute/DeployMiniGamePointShop.s.sol --rpc-url <RPC_URL> --broadcast
```

## Testing

### Run All Tests
```bash
forge test --match-contract MiniGamePointShopTest -vv
```

### Test Coverage
The test suite covers:
- Constructor validation
- Token claiming (all types)
- Signature verification
- Error conditions
- Admin functions
- Security features
- Edge cases

## Gas Optimization

- Uses `calldata` for request parameters
- Efficient storage layout
- Minimal external calls
- Optimized signature verification

## Events

### TokensClaimed
Emitted when tokens are successfully claimed:
```solidity
event TokensClaimed(
    address indexed user,
    address indexed token,
    uint256 amount,
    uint256 tokenId,
    TokenType tokenType,
    uint256 nonce
);
```

### VerifierUpdated
Emitted when verifier address is changed:
```solidity
event VerifierUpdated(
    address indexed oldVerifier,
    address indexed newVerifier
);
```

### TokensWithdrawn
Emitted when admin withdraws tokens:
```solidity
event TokensWithdrawn(
    address indexed to,
    address indexed token,
    uint256 amount,
    uint256 tokenId,
    TokenType tokenType
);
```

## Error Handling

The contract uses custom errors for efficient gas usage:
- `ZeroAddress()` - Invalid address parameter
- `InvalidVerifier()` - Invalid verifier address
- `InvalidSignature()` - Signature verification failed
- `InvalidNonce()` - Nonce already used
- `ExpiredDeadline()` - Claim deadline passed
- `InvalidTokenType()` - Token type mismatch
- `InsufficientBalance()` - Contract lacks sufficient tokens
- `TransferFailed()` - Token transfer failed
- `InvalidAmount()` - Invalid amount parameter
- `InvalidTokenId()` - Invalid token ID

## Integration Examples

### Frontend Integration
```javascript
// Create claim request
const request = {
    user: userAddress,
    token: tokenAddress,
    amount: amount,
    tokenId: tokenId,
    nonce: nonce,
    deadline: deadline,
    tokenType: tokenType
};

// Get signature from verifier
const signature = await verifier.signRequest(request);

// Submit claim
await contract.claimERC20(request, signature);
```

### Backend Verification
```javascript
// Verify request hash
const requestHash = contract.getClaimRequestHash(request);
const messageHash = ethers.utils.hashMessage(ethers.utils.arrayify(requestHash));

// Recover signer
const signer = ethers.utils.recoverAddress(messageHash, signature);

// Verify signer is authorized verifier
if (signer !== verifierAddress) {
    throw new Error('Invalid signature');
}
```

## Best Practices

1. **Verifier Security**: Keep verifier private keys secure
2. **Nonce Management**: Use cryptographically secure nonces
3. **Deadline Setting**: Set reasonable deadlines for claims
4. **Gas Estimation**: Estimate gas costs for claim operations
5. **Error Handling**: Implement proper error handling in frontend
6. **Monitoring**: Monitor contract events for claim activities

## License

GPL-3.0
