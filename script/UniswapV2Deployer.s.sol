// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract UniswapV2Deployer is Script, StdCheats {
    address public constant UNISWAP_V2_FACTORY = 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9;
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant UNISWAP_V2_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;

    function run() public {
        deployCodeTo(
            "UniswapV2Factory.sol:UniswapV2Factory",
            abi.encode(
                address(54321)
            ),
            UNISWAP_V2_FACTORY
        );

        deployCodeTo(
            "WETH.sol:WETH",
            WETH
        );

        deployCodeTo(
            "UniswapV2Router02.sol:UniswapV2Router02",
            abi.encode(
                UNISWAP_V2_FACTORY,
                WETH
            ),
            UNISWAP_V2_ROUTER
        );
    }
}