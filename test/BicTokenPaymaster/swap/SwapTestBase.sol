// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BicTokenPaymasterTestBase.sol";
import "./UniswapV2Deployer.sol";

contract SwapTestBase is BicTokenPaymasterTestBase {
//    IUniswapV2Factory public factory;
    function setUp() public virtual override {
        UniswapV2Deployer deployer = new UniswapV2Deployer();
        deployer.run();
        super.setUp();
    }
}