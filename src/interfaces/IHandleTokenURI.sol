// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

/// @title A token URI interface for creating and interacting with token URIs
/// @dev Details about token URIs can be found in the HandleTokenURI contract
interface IHandleTokenURI {
    function getTokenURI(
        uint256 tokenId,
        string memory localName,
        string memory namespace
    ) external view returns (string memory);
}
