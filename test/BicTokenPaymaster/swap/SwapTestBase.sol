// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BicTokenPaymasterTestBase.sol";
import "../../../script/UniswapV2Deployer.s.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract SwapTestBase is BicTokenPaymasterTestBase {
    IUniswapV2Factory public uniswapV2Factory;
    IUniswapV2Router02 public uniswapV2Router;
    WETH public weth;
    function setUp() public virtual override {
        UniswapV2Deployer deployer = new UniswapV2Deployer();
        deployer.run();
        super.setUp();
        uniswapV2Factory = IUniswapV2Factory(deployer.UNISWAP_V2_FACTORY());
        uniswapV2Router = IUniswapV2Router02(deployer.UNISWAP_V2_ROUTER());
        weth = WETH(payable(deployer.WETH()));

    }
}