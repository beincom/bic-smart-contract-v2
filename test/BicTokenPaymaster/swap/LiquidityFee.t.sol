// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BicTokenPaymasterTestBase.sol";

contract LiquidityFee is BicTokenPaymasterTestBase {
    function test_FeeToSetterExist_toMakeSureUniswapHasBeenDeployWell() public {
        assertEq(uniswapV2Factory.feeToSetter(), address(54321));
    }


}