// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Address} from '@openzeppelin/contracts/utils/Address.sol';
import {ERC2981} from '@openzeppelin/contracts/token/common/ERC2981.sol';
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC721Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';

import {TokenIdentifiers} from "../utils/TokenIdentifiers.sol";
import {IDupHandles} from "../interfaces/IDupHandles.sol";
import {IHandleTokenURI} from '../interfaces/IHandleTokenURI.sol';

/// @title Handles contract for managing unique namespace-based identifiers.
/// @dev This contract utilizes ERC721Upgradeable for tokenization of handles. Each handle represents a unique identifier within a specified namespace.
///
/// Handles are formed by appending a local name to a namespace, separated by "0x40". This contract allows minting and burning of handles, alongside basic management of their attributes.
///
/// Designed to be used with a Transparent upgradeable proxy without requiring an initializer.
contract DupHandles is ERC721Upgradeable, ERC2981, IDupHandles {
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Address of the controllers with administrative privileges.
    EnumerableSet.AddressSet private _controllers;
    /// @notice Address of the operator who can perform certain restricted operations.
    address public OPERATOR;
    /// @notice The namespace under which all handles are created.
    string private _namespace;
    /// @notice Total number of minted handles.
    /// @dev We used 31 to fit the handle in a single slot, with `.name` that restricted localName to use 26 characters.
    uint256 private _totalSupply;


    /// @dev Mapping from token ID to the local name of the handle.
    mapping(uint256 tokenId => string localName) internal _localNames;

    mapping(string localName => uint16 supply) internal _localNameSupply;

    /// @dev Address of the contract responsible for generating token URIs.
    address internal _handleTokenURIContract;

    /// @notice Ensures that the function is called only by the operator.
    modifier onlyOperator() {
        if (msg.sender != OPERATOR) {
            revert NotOperator();
        }
        _;
    }

    /// @notice Ensures that the function is called only by the controller.
    modifier onlyController() {
        if (!_controllers.contains(msg.sender)) {
            revert NotController();
        }
        _;
    }

    constructor() {}

    /// @notice Initializes the contract with the given namespace and ERC721 token details.
    /// @dev Initializes the contract with the given namespace and ERC721 token details.
    /// @param namespace The namespace under which all handles are created.
    /// @param name The name of the ERC721 token.
    /// @param symbol The symbol of the ERC721 token.
    /// @param operator The address of the operator who can perform certain restricted operations.
    function initialize(
        string memory namespace,
        string memory name,
        string memory symbol,
        address operator
    ) public initializer {
        __ERC721_init(name, symbol);
        _namespace = namespace;
        OPERATOR = operator;
    }

    /// @notice Returns the total supply of minted tokens.
    /// @dev Returns the total supply of minted tokens.
    /// @return The total supply of minted tokens.
    function totalSupply() external view virtual override returns (uint256) {
        return _totalSupply;
    }

    /// @notice Sets a new controller address.
    /// @dev Sets a new controller address for the contract with restricted privileges.
    /// @param controller The address of the new controller.
    function setController(address controller) external onlyOperator {
        if(_controllers.contains(controller)) {
            revert AlreadyController();
        }
        _controllers.add(controller);
        emit SetController(controller);
    }

    /// @notice Removes a controller address.
    /// @dev Removes a controller address for the contract with restricted privileges.
    /// @param controller The address of the controller to remove.
    function removeController(address controller) external onlyOperator {
        if(!_controllers.contains(controller)) {
            revert NotController();
        }
        _controllers.remove(controller);
        emit RemoveController(controller);
    }

    /// @notice Sets a new operator address.
    /// @dev Sets a new operator address for the contract with restricted privileges.
    /// @param operator The address of the new operator.
    function setOperator(address operator) external onlyOperator {
        OPERATOR = operator;
        emit SetOperator(operator);
    }

    /// @notice Retrieves the controllers address.
    /// @dev Retrieves the controllers address.
    /// @return The controllers address.
    function getControllers() external view returns (address[] memory) {
        return _controllers.values();
    }

    /// @notice Sets the contract address responsible for handle token URI generation.
    /// @dev Sets the contract address responsible for generating token URIs with restricted privileges.
    /// @param handleTokenURIContract The address of the contract responsible for generating token URIs.
    function setHandleTokenURIContract(address handleTokenURIContract) external override onlyOperator {
        _handleTokenURIContract = handleTokenURIContract;
        emit BatchMetadataUpdate({fromTokenId: 0, toTokenId: type(uint256).max});
    }

    /// @notice Returns the address of the contract generating token URIs.
    /// @dev Returns the address of the contract responsible for generating token URIs.
    /// @return The address of the contract responsible for generating token URIs.
    function getHandleTokenURIContract() external view override returns (address) {
        return _handleTokenURIContract;
    }

    /// @notice Returns the URI for a token based on its ID.
    /// @dev Returns the URI for a token based on its ID with required NFT minted
    /// @param tokenId The ID of the token.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return IHandleTokenURI(_handleTokenURIContract).getTokenURI(tokenId, _localNames[tokenId], _namespace);
    }

    /// @notice Mints a new handle with a given local name for the specified address.
    /// @dev Mints a new handle with a given local name for the specified address.
    /// @param to The address to mint the handle for.
    /// @param localName The local name of the handle.
    /// @return The ID of the minted handle.
    function mintHandle(
        address to,
        string calldata localName
    ) external onlyController returns (uint256) {
        return _mintHandle(to, localName);
    }

    /// @notice Burns a handle with a specified token ID.
    /// @dev Burns a handle with a specified token ID.
    /// @param tokenId The ID of the handle to burn.
    function burn(uint256 tokenId) external {
        if (msg.sender != ownerOf(tokenId)) {
            revert NotOwner();
        }
        --_totalSupply;
        _burn(tokenId);
        delete _localNames[tokenId];
    }


    /// @notice ERC2981 royalty information for a given token ID and sale price.
    /// @dev ERC2981 royalty information for a given token ID and sale price.
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyOperator {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
        emit SetTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /// @notice Checks if a handle exists by its token ID.
    /// @dev Checks if a handle exists by its token ID.
    function exists(uint256 tokenId) external view override returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /// @notice Retrieves the namespace of the handles.
    /// @dev Retrieves the namespace of the handles.
    /// @return The namespace of the handles.
    function getNamespace() public view virtual returns (string memory) {
        return _namespace;
    }

    /// @notice Returns the hash of the namespace string.
    /// @dev Returns the hash of the namespace string.
    /// @return The hash of the namespace string.
    function getNamespaceHash() external view override returns (bytes32) {
        return keccak256(bytes(_namespace));
    }

    /// @notice Retrieves the local name of a handle by its token ID.
    /// @dev Retrieves the local name of a handle by its token ID.
    /// @param tokenId The ID of the handle.
    /// @return The local name of the handle.
    function getLocalName(uint256 tokenId) public view override returns (string memory) {
        string memory localName = _localNames[tokenId];
        if (bytes(localName).length == 0) {
            revert DoesNotExist();
        }
        return _localNames[tokenId];
    }

    /// @notice Constructs the complete handle from a token ID.
    /// @dev Constructs the complete handle from a token ID.
    /// @param tokenId The ID of the handle.
    /// @return The handle with the namespace and local name.
    function getHandle(uint256 tokenId) public view override returns (string memory) {
        string memory localName = getLocalName(tokenId);
        return string.concat(_namespace, '/@', localName);
    }

    /// @notice Generates a token ID based on a given local name.
    /// @dev Generates a token ID based on a given local name.
    /// @param localName The local name of the handle.
    /// @return The token ID of the handle.
    function getTokenId(string memory localName) public view override returns (uint256) {
        return TokenIdentifiers.getTokenId(localName, _localNameSupply[localName]);
    }

    /// @notice Get supply of a given local name.
    /// @param localName The local name of the handle.
    /// @return The supply of a given local name.
    function getSupplyOfLocalName(string memory localName) public view override returns (uint256) {
        return _localNameSupply[localName];
    }

    /// @notice Generates a token ID based on a given local name.
    /// @dev Generates a token ID based on a given local name.
    /// @param localName The local name of the handle.
    /// @param index The index supply of the handle.
    /// @return The token ID of the handle.
    function getTokenIdByIndex(string memory localName, uint16 index) public pure override returns (uint256) {
        return TokenIdentifiers.getTokenId(localName, index);
    }

    /// @notice Get the index supply of a token ID.
    /// @param tokenId The ID of the handle.
    /// @return The supply index of the token Id.
    function getSupplyIndex(uint256 tokenId) public pure override returns (uint256) {
        return TokenIdentifiers.tokenIndex(tokenId);
    }

    /// @notice Get all owners of a given local name.
    /// @param localName The local name of the handle.
    function getAllOwnersOfLocalName(string memory localName) public view returns (address[] memory) {
        uint16 supply = _localNameSupply[localName];
        address[] memory owners = new address[](supply);
        for (uint16 index = 0; index < supply; index++) {
            address ownerOfIndex = ownerOf(getTokenIdByIndex((localName), index));
            owners[index] = ownerOfIndex;
        }
        return owners;
    }

    /// @notice Returns true if this contract implements the interface defined by `interfaceId`.
    /// @dev Returns true if this contract implements the interface defined by `interfaceId`.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721Upgradeable, ERC2981, IERC165) returns (bool) {
        return (
            interfaceId == type(IDupHandles).interfaceId ||
            ERC2981.supportsInterface(interfaceId) ||
            ERC721Upgradeable.supportsInterface(interfaceId)
        );
    }

    //////////////////////////////////////
    ///        INTERNAL FUNCTIONS      ///
    //////////////////////////////////////

    /// @dev Mints a new handle with the specified local name for a given address. This function generates a token ID based on the local name,
    /// increments the total supply, mints the token, stores the local name associated with the token ID, and emits a HandleMinted event.
    /// @param to The address to which the new token will be minted.
    /// @param localName The local part of the handle to be minted.
    /// @return tokenId The unique token ID of the minted handle.
    function _mintHandle(address to, string calldata localName) internal returns (uint256) {
        uint16 index = _localNameSupply[localName];
        uint256 tokenId = TokenIdentifiers.getTokenId(localName, index);
        ++_totalSupply;
        _mint(to, tokenId);
        _localNames[tokenId] = localName;
        _localNameSupply[localName] = index + 1;
        emit HandleMinted(localName, _namespace, tokenId, to, block.timestamp);
        return tokenId;
    }
}

