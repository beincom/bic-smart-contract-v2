// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract UniswapV2Deployer is Script, StdCheats {
    function run() public {
        deployCodeTo(
            "UniswapV2Factory.sol:UniswapV2Factory",
            0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9
        );

        deployCodeTo(
            "WETH9.sol:WETH9",
            0x82aF49447D8a07e3bd95BD0d56f35241523fBab1
        );

        deployCodeTo(
            "UniswapV2Router02.sol:UniswapV2Router02",
            abi.encode(
                0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9,
                0x82aF49447D8a07e3bd95BD0d56f35241523fBab1
            ),
            0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24
        );
    }
}