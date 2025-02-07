// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

// Library
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Internal
import {IHandleTokenURI} from "../interfaces/IHandleTokenURI.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Handle Token URI Generator
/// @dev This contract is responsible for generating a token URI based on metadata elements associated with namespaces. It uses owner controls to manage who can set these metadata elements.
contract HandleTokenURI is IHandleTokenURI, Ownable {
    /**
     * @notice using strings library for uint256
     */
    using Strings for uint256;

    struct NameElement {
        string imageDescription; // Description of the image
        string imageURI; // URI for the image
    }
    mapping(string => NameElement) nameElements;

    /// @notice Emitted when a name element is set
    /// @param imageDescription the description of the name (aka Beincom - Earning Username)
    /// @param imageURI the uri for svg background name image
    event SetNameElement(
        string namespace,
        string imageDescription,
        string imageURI
    );

    constructor(address _owner) Ownable(_owner) {
        
    }


    /// @notice Sets the metadata elements for a given namespace.
    /// @dev This function is accessible only to operators.
    /// @param namespace The namespace to associate with the metadata elements.
    /// @param imageDescription The description of the image for the namespace.
    /// @param imageURI The URI for the image for the namespace.
    function setNameElement(
        string memory namespace,
        string memory imageDescription,
        string memory imageURI
    ) external onlyOwner {
        nameElements[namespace] = NameElement(imageDescription, imageURI);
        emit SetNameElement(namespace, imageDescription, imageURI);
    }

    /// @notice Retrieves the metadata elements associated with a specific namespace.
    /// @param namespace The namespace for which metadata elements are queried.
    /// @return imageDescription The description of the image.
    /// @return imageURI The URI of the image.
    function getNameElement(
        string memory namespace
    ) external view returns (string memory, string memory) {
        return (
            nameElements[namespace].imageDescription,
            nameElements[namespace].imageURI
        );
    }

    /// @dev Internal function to concatenate the base image URI with the local name query parameter.
    /// @param namespace The namespace used to retrieve the base URI.
    /// @param tokenId The local name used as a query parameter.
    /// @return The full image URI including the query parameter.
    function getImageURI(
        string memory namespace,
        uint256 tokenId
    ) internal view returns (string memory) {
        return
            string.concat(
                nameElements[namespace].imageURI,
                "/",
                Strings.toString(tokenId)
            );
    }

    /// @dev Internal function to generate the image description including the local name.
    /// @param namespace The namespace used to retrieve the base description.
    /// @param localName The local name appended to the base description.
    /// @return The full image description.
    function getImageDescription(
        string memory namespace,
        string memory localName
    ) internal view returns (string memory) {
        return
            string.concat(
                '"',
                nameElements[namespace].imageDescription,
                localName,
                '"'
            );
    }

    /// @notice Generates a complete token URI with metadata for a specific token.
    /// @param tokenId The identifier for the token.
    /// @param localName The local name associated with the token.
    /// @param namespace The namespace under which the token was minted.
    /// @return The complete token URI in base64-encoded JSON format.
    function getTokenURI(
        uint256 tokenId,
        string memory localName,
        string memory namespace
    ) external view override returns (string memory) {
        return
            string.concat(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        string.concat(
                            '{"name":"@',
                            localName,
                            '","description":',
                            getImageDescription(namespace, localName),
                            ',"image":"',
                            getImageURI(namespace, tokenId),
                            '","attributes":[{"display_type":"number","trait_type":"ID","value":"',
                            tokenId.toString(),
                            '"},{"trait_type":"NAMESPACE","value":"',
                            namespace,
                            '"},{"trait_type":"LENGTH","value":"',
                            bytes(localName).length.toString(),
                            '"}]}'
                        )
                    )
                )
            );
    }
}
