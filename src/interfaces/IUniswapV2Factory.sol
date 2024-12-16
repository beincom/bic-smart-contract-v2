// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address);
    function createPair(address tokenA, address tokenB) external returns (address);
}