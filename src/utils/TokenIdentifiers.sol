// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

library TokenIdentifiers {
    uint8 constant BASE_NAME_BITS = 240;
    uint8 constant INDEX_BITS = 16;

    uint256 constant INDEX_MASK = (uint256(1) << INDEX_BITS) - 1;
    uint256 constant BASE_NAME_MASK = ((uint256(1) << BASE_NAME_BITS) - 1) ^ INDEX_MASK;

    function tokenIndex(uint256 _id) internal pure returns (uint256) {
        return _id & INDEX_MASK;
    }

    function tokenBaseName(uint256 _id) internal pure returns (uint256) {
        return _id & BASE_NAME_MASK;
    }

    function getTokenId(string memory localName, uint16 index) internal pure returns (uint256) {
        uint256 hashedLocalName = uint256(keccak256(bytes(localName)));
        uint256 basedName = hashedLocalName & BASE_NAME_MASK;
        uint256 shiftedIndex = uint256(index) & INDEX_MASK;
        uint256 tokenId = basedName | shiftedIndex;
        
        return tokenId;
    }
}