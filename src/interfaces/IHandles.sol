// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";


/// @title A Handles interface for creating and interacting with handles
/// @dev Details about handles can be found in the Handles contract
interface IHandles is IERC721 {
    event SetOperator(address indexed operator);
    event RemoveController(address indexed controller);
    event SetController(address indexed controller);
    event SetTokenRoyalty(uint256 indexed tokenId, address indexed receiver, uint96 feeNumerator);
    event HandleMinted(string handle, string namespace, uint256 handleId, address to, uint256 timestamp);
    event BatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId);

    error NotOwner();
    error NotOperator();
    error NotController();
    error AlreadyController();
    error DoesNotExist();

    function mintHandle(address to, string calldata localName) external returns (uint256);

    function burn(uint256 tokenId) external;

    function getNamespace() external view returns (string memory);

    function getNamespaceHash() external view returns (bytes32);

    function exists(uint256 tokenId) external view returns (bool);

    function getLocalName(uint256 tokenId) external view returns (string memory);

    function getHandle(uint256 tokenId) external view returns (string memory);

    function getTokenId(string memory localName) external pure returns (uint256);

    function totalSupply() external view returns (uint256);

    function setController(address controller) external;

    function getHandleTokenURIContract() external view returns (address);

    function setHandleTokenURIContract(address handleTokenURIContract) external;
}
