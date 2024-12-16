// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

library BicTokenPaymasterStorage {
    /// @custom:storage-location erc7201:storage.BicTokenPaymaster
    struct Data {
        mapping(address => bool) _isBlocked;
    }

    // keccak256(abi.encode(uint256(keccak256("storage.BicTokenPaymaster")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BicTokenPaymasterStorageLocation =
        0x087f1ed82768b920bbf7f524ae10adce75c43e9e7db2301bbd943b1365e05e00;

    function _getStorageLocation()
        internal
        pure
        returns (BicTokenPaymasterStorage.Data storage $)
    {
        assembly {
            $.slot := BicTokenPaymasterStorageLocation
        }
    }
}
