// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

library BicStorage {
    struct Data {
        // LF (Liquidity Fee) Variables
        uint256 _LFStartTime; // slot 0
        uint256 _LFReduction; // slot 1
        uint256 _LFPeriod; // slot 2
        uint256 _maxLF; // slot 3
        uint256 _minLF; // slot 4
        uint256 _minSwapBackAmount; // slot 5
        uint256 _accumulatedLF; // slot 6
        // Addresses
        address _liquidityTreasury; // slot 7
        address _uniswapV2Pair; // slot 8
        address _uniswapV2Router; // slot 9
        // Status Flags (packed into a single storage slot)
        bool _prePublic;
        bool _swapBackEnabled;
        bool _swapping;
        // Mappings
        mapping(address => uint256) _prePublicWhitelist;
        mapping(address => uint256) _coolDown;
        mapping(uint256 => PrePublic) _prePublicRounds;
        mapping(address => bool) _isExcluded;
        mapping(address => bool) _isPool;
        mapping(address => bool) _isBlocked;
    }

    // Pre-public structure
    struct PrePublic {
        uint256 category;
        uint256 startTime;
        uint256 endTime;
        uint256 coolDown;
        uint256 maxAmountPerBuy;
    }

    // Keccak-256 hash of "storage.B139Storage" minus 1, masked to fit storage slot
    bytes32 private constant BicTokenPaymasterStorageLocation =
    0xd959cca23720948e5f992e1bef099a518994cc8b384c796f2b25ba30718fb300;

    function _getStorageLocation()
        internal
        pure
        returns (BicStorage.Data storage $)
    {
        assembly {
            $.slot := BicTokenPaymasterStorageLocation
        }
    }
}