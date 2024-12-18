// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IUniswapV2Router} from "../../src/interfaces/IUniswapV2Router.sol";

library BICStorageV7 {
    struct Data {
        address entryPointv7;
    }
    bytes32 private constant BicTokenPaymasterStorageLocation =
        0xd959cca23720948e5f992e1bef099a518994cc8b384c796f2b25ba30718fb307;

    function _getStorageLocation()
        internal
        pure
        returns (BICStorageV7.Data storage $)
    {
        assembly {
            $.slot := BicTokenPaymasterStorageLocation
        }
    }
}
