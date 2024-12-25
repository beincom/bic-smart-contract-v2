// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

library BicStorage {
    struct Data {
        bool _isEnabledLFReduction;
        bool _swapBackEnabled;
        bool _swapping;
        // Liquidity treasury
        address _liquidityTreasury;
        // Dex
        address _uniswapV2Pair;
        address _uniswapV2Router;
        // LF
        uint256 _LFStartTime;
        uint256 _LFReduction;
        uint256 _LFPeriod;
        uint256 _maxLF;
        uint256 _minLF;
        uint256 _minSwapBackAmount;
        uint256 _accumulatedLF;
        mapping(address => bool) _isExcluded;
        mapping(address => bool) _isPool;
        mapping(address => bool) _isBlocked;
    }

    // keccak256(abi.encode(uint256(keccak256("storage.B139Storage")) - 1)) & ~bytes32(uint256(0xff))
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
