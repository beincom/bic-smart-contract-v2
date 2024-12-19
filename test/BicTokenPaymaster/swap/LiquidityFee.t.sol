// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SwapTestBase} from "./SwapTestBase.sol";

contract LiquidityFee is SwapTestBase {
    function test_FeeToSetterExist_toMakeSureUniswapHasBeenDeployWell() public {
        assertEq(uniswapV2Factory.feeToSetter(), address(54321));
    }


}