// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";

/// @title ERC1155ReceiverFacet
/// @notice Facet to enable the diamond to receive ERC1155 tokens via safe transfers and mints
contract ERC1155ReceiverFacet {
    /// @notice Initializer to register ERC1155Receiver support in diamond storage (ERC165)
    function initERC1155Receiver() external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IERC1155Receiver).interfaceId] = true;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}


