// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

library BicStorage {
    struct Data {
        // LF (Liquidity Fee) Variables
        uint256 _LFStartTime;
        uint256 _LFReduction;
        uint256 _LFPeriod;
        uint256 _maxLF;
        uint256 _minLF;
        uint256 _minSwapBackAmount;
        uint256 _accumulatedLF;
        // Addresses
        address _liquidityTreasury;
        address _uniswapV2Pair;
        address _uniswapV2Router;
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
        // New V2 storage variables
        uint256 _newValue;
        address _newAddress;
    }

    // Pre-public structure
    struct PrePublic {
        uint256 category;
        uint256 startTime;
        uint256 endTime;
        uint256 coolDown;
        uint256 maxAmountPerBuy;
    }

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
