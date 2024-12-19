// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BicTokenPaymasterTestBase.sol";
import "../../../script/UniswapV2Deployer.s.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract SwapTestBase is BicTokenPaymasterTestBase {
    IUniswapV2Factory public uniswapV2Factory;
    function setUp() public virtual override {
        UniswapV2Deployer deployer = new UniswapV2Deployer();
        deployer.run();
        super.setUp();
        uniswapV2Factory = IUniswapV2Factory(deployer.UNISWAP_V2_FACTORY());
    }
}