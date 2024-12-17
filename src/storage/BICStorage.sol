// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IUniswapV2Router} from "../interfaces/IUniswapV2Router.sol";

library BICStorage {
    struct Data {
        bool _prePublic;
        bool _isEnabledLFReduction;
        bool _swapBackEnabled;
        bool _swapping;
        bool _enabledMaxAllocation;
        // Controller
        address _upgradeController;
        address _prePublicController;
        address _LFController;
        address _maxAllocationController;
        address _treasuryController;
        address _liquidityTreasury;
        // Dex
        address _uniswapV2Pair;
        address _tokenInPair;
        IUniswapV2Router _uniswapV2Router;
        // LF
        uint256 _LFStartTime;
        uint256 _LFReduction;
        uint256 _LFPeriod;
        uint256 _maxLF;
        uint256 _minLF;
        uint256 _minSwapBackAmount;
        uint256 _maxAllocation;
        uint256 _accumulatedLF;
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

    // keccak256(abi.encode(uint256(keccak256("storage.B139Storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BicTokenPaymasterStorageLocation =
        0xd959cca23720948e5f992e1bef099a518994cc8b384c796f2b25ba30718fb300;

    function _getStorageLocation()
        internal
        pure
        returns (BICStorage.Data storage $)
    {
        assembly {
            $.slot := BicTokenPaymasterStorageLocation
        }
    }
}
