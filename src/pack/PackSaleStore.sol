// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TokenStore} from "../extension/TokenStore.sol";
import {ITokenBundle} from "../extension/interface/ITokenBundle.sol";

/**
 * @title PackSaleStore
 * @notice A marketplace contract for selling token packages with signature-based authorization
 * @dev Extends TokenStore to handle ERC20/ERC721/ERC1155 token bundles
 */
contract PackSaleStore is Ownable, ReentrancyGuard, TokenStore {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Package information structure
     * @param capacity Maximum number of packages that can be sold
     * @param sold Number of packages already sold
     * @param price Price per package in the specified currency
     * @param currency Address of the ERC20 token used for payment (address(0) for native ETH)
     * @param active Whether the package is available for purchase
     */
    struct PackageInfo {
        uint256 capacity;
        uint256 sold;
        uint256 price;
        address currency;
        bool active;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Address authorized to sign purchase transactions
    address public operator;

    /// @notice Counter for generating unique package IDs
    uint256 public nextPackageId;

    /// @notice Mapping from package ID to package information
    mapping(uint256 => PackageInfo) public packages;

    /// @notice Mapping to track used transaction hashes to prevent replay attacks
    mapping(bytes32 => bool) public usedHashes;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new package is registered
    event PackageRegistered(
        uint256 indexed packageId,
        uint256 capacity,
        uint256 price,
        address currency,
        Token[] assets
    );

    /// @notice Emitted when a package is purchased
    event PackagePurchased(
        uint256 indexed packageId,
        address indexed buyer,
        uint256 price,
        address currency,
        bytes32 transactionHash
    );

    /// @notice Emitted when the operator is updated
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    /// @notice Emitted when a package is deactivated
    event PackageDeactivated(uint256 indexed packageId);

    /// @notice Emitted when a package is reactivated
    event PackageReactivated(uint256 indexed packageId);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidPackageId();
    error PackageNotActive();
    error PackageSoldOut();
    error InvalidSignature();
    error HashAlreadyUsed();
    error InvalidTimeWindow();
    error InsufficientPayment();
    error EmptyAssets();
    error ZeroAddress();
    error InvalidCapacity();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize the PackSaleStore contract
     * @param _owner Address that will own the contract
     * @param _operator Address authorized to sign purchase transactions
     */
    constructor(address _owner, address _operator) Ownable(_owner) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register a new package for sale
     * @param _capacity Maximum number of packages that can be sold
     * @param _assets Array of tokens that make up the package
     * @param _price Price per package in the specified currency
     * @param _currency Address of the ERC20 token for payment (address(0) for ETH)
     * @return packageId The ID of the newly registered package
     */
    function registerPackage(
        uint256 _capacity,
        Token[] calldata _assets,
        uint256 _price,
        address _currency
    ) external onlyOwner returns (uint256 packageId) {
        if (_capacity == 0) revert InvalidCapacity();
        if (_assets.length == 0) revert EmptyAssets();

        packageId = nextPackageId++;

        // Store the package assets as a bundle
        _storeTokens(msg.sender, _assets, "", packageId);

        // Set package information
        packages[packageId] = PackageInfo({
            capacity: _capacity,
            sold: 0,
            price: _price,
            currency: _currency,
            active: true
        });

        emit PackageRegistered(packageId, _capacity, _price, _currency, _assets);
    }

    /**
     * @notice Update the operator address
     * @param _newOperator New operator address
     */
    function setOperator(address _newOperator) external onlyOwner {
        if (_newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = _newOperator;
        emit OperatorUpdated(oldOperator, _newOperator);
    }

    /**
     * @notice Deactivate a package (prevent further sales)
     * @param _packageId ID of the package to deactivate
     */
    function deactivatePackage(uint256 _packageId) external onlyOwner {
        if (_packageId >= nextPackageId) revert InvalidPackageId();
        packages[_packageId].active = false;
        emit PackageDeactivated(_packageId);
    }

    /**
     * @notice Reactivate a package (allow sales again)
     * @param _packageId ID of the package to reactivate
     */
    function reactivatePackage(uint256 _packageId) external onlyOwner {
        if (_packageId >= nextPackageId) revert InvalidPackageId();
        packages[_packageId].active = true;
        emit PackageReactivated(_packageId);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Purchase a package with signature verification
     * @param _packageId ID of the package to purchase
     * @param _validUntil Timestamp until which the signature is valid
     * @param _validAfter Timestamp after which the signature is valid
     * @param _signature Operator's signature authorizing the purchase
     */
    function buyPackage(
        uint256 _packageId,
        uint256 _validUntil,
        uint256 _validAfter,
        bytes calldata _signature
    ) external payable nonReentrant {
        // Validate package ID
        if (_packageId >= nextPackageId) revert InvalidPackageId();

        PackageInfo storage package = packages[_packageId];

        // Check if package is active and available
        if (!package.active) revert PackageNotActive();
        if (package.sold >= package.capacity) revert PackageSoldOut();

        // Verify time window
        if (block.timestamp < _validAfter || block.timestamp > _validUntil) {
            revert InvalidTimeWindow();
        }

        // Generate and verify transaction hash
        bytes32 transactionHash = _generateHash(_packageId, _validUntil, _validAfter);
        
        if (usedHashes[transactionHash]) revert HashAlreadyUsed();
        if (!_verifySignature(transactionHash, _signature)) revert InvalidSignature();

        // Mark hash as used
        usedHashes[transactionHash] = true;

        // Process payment
        _processPayment(package.currency, package.price);

        // Transfer assets to buyer
        _releaseTokens(msg.sender, _packageId);

        // Update sold count
        package.sold++;

        emit PackagePurchased(_packageId, msg.sender, package.price, package.currency, transactionHash);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get package information
     * @param _packageId ID of the package
     * @return Package information struct
     */
    function getPackageInfo(uint256 _packageId) external view returns (PackageInfo memory) {
        if (_packageId >= nextPackageId) revert InvalidPackageId();
        return packages[_packageId];
    }

    /**
     * @notice Get package assets
     * @param _packageId ID of the package
     * @return assets Array of tokens in the package
     */
    function getPackageAssets(uint256 _packageId) external view returns (Token[] memory assets) {
        if (_packageId >= nextPackageId) revert InvalidPackageId();
        
        uint256 count = getTokenCountOfBundle(_packageId);
        assets = new Token[](count);
        
        for (uint256 i = 0; i < count; i++) {
            assets[i] = getTokenOfBundle(_packageId, i);
        }
    }

    /**
     * @notice Check if a transaction hash has been used
     * @param _packageId Package ID
     * @param _validUntil Valid until timestamp
     * @param _validAfter Valid after timestamp
     * @return Whether the hash has been used
     */
    function isHashUsed(
        uint256 _packageId,
        uint256 _validUntil,
        uint256 _validAfter
    ) external view returns (bool) {
        bytes32 hash = _generateHash(_packageId, _validUntil, _validAfter);
        return usedHashes[hash];
    }

    /**
     * @notice Generate transaction hash for given parameters
     * @param _packageId Package ID
     * @param _validUntil Valid until timestamp
     * @param _validAfter Valid after timestamp
     * @return Transaction hash
     */
    function generateHash(
        uint256 _packageId,
        uint256 _validUntil,
        uint256 _validAfter
    ) external pure returns (bytes32) {
        return _generateHash(_packageId, _validUntil, _validAfter);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Generate transaction hash
     * @param _packageId Package ID
     * @param _validUntil Valid until timestamp
     * @param _validAfter Valid after timestamp
     * @return Transaction hash
     */
    function _generateHash(
        uint256 _packageId,
        uint256 _validUntil,
        uint256 _validAfter
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_packageId, _validUntil, _validAfter));
    }

    /**
     * @notice Verify operator signature
     * @param _hash Transaction hash to verify
     * @param _signature Signature to verify
     * @return Whether signature is valid
     */
    function _verifySignature(bytes32 _hash, bytes calldata _signature) internal view returns (bool) {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(_hash);
        address signer = ethSignedMessageHash.recover(_signature);
        return signer == operator;
    }

    /**
     * @notice Process payment for package purchase
     * @param _currency Currency address (address(0) for ETH)
     * @param _amount Amount to pay
     */
    function _processPayment(address _currency, uint256 _amount) internal {
        if (_currency == address(0)) {
            // Native ETH payment
            if (msg.value < _amount) revert InsufficientPayment();
            
            // Refund excess ETH
            if (msg.value > _amount) {
                payable(msg.sender).transfer(msg.value - _amount);
            }
        } else {
            // ERC20 token payment
            if (msg.value > 0) revert InsufficientPayment(); // Should not send ETH for ERC20 payment
            IERC20(_currency).safeTransferFrom(msg.sender, address(this), _amount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                           OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Withdraw ETH from the contract
     * @param _to Address to withdraw to
     * @param _amount Amount to withdraw (0 to withdraw all)
     */
    function withdrawETH(address payable _to, uint256 _amount) external onlyOwner {
        if (_to == address(0)) revert ZeroAddress();
        
        uint256 balance = address(this).balance;
        uint256 withdrawAmount = _amount == 0 ? balance : _amount;
        
        if (withdrawAmount > balance) revert InsufficientPayment();
        
        _to.transfer(withdrawAmount);
    }

    /**
     * @notice Withdraw ERC20 tokens from the contract
     * @param _token Token contract address
     * @param _to Address to withdraw to
     * @param _amount Amount to withdraw (0 to withdraw all)
     */
    function withdrawToken(address _token, address _to, uint256 _amount) external onlyOwner {
        if (_token == address(0) || _to == address(0)) revert ZeroAddress();
        
        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        uint256 withdrawAmount = _amount == 0 ? balance : _amount;
        
        if (withdrawAmount > balance) revert InsufficientPayment();
        
        token.safeTransfer(_to, withdrawAmount);
    }

    /**
     * @notice Emergency function to release stuck assets
     * @param _packageId Package ID to release assets from
     * @param _to Address to send assets to
     */
    function emergencyReleaseAssets(uint256 _packageId, address _to) external onlyOwner {
        if (_packageId >= nextPackageId) revert InvalidPackageId();
        if (_to == address(0)) revert ZeroAddress();
        
        _releaseTokens(_to, _packageId);
    }
}
