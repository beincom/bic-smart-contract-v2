// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BicTokenPaymasterTestBase.sol";

contract LiquidityFee is BicTokenPaymasterTestBase {
    address public bicUniswapPair;
    address public randomUser = vm.addr(0xabcde);

    uint256 public initPoolBicAmount = 800_000_000 * 1e18;
    uint256 public initPoolEthAmount = 5 ether;
    function setUp() public override {
        super.setUp();
        bicUniswapPair = uniswapV2Factory.getPair(address(bic), address(weth));

        vm.deal(owner, initPoolEthAmount);
        vm.startPrank(owner);

        // add liqudiity to BIC-WETH pool
        assertGe(bic.balanceOf(owner), initPoolBicAmount, "owner should have enough BIC to add liquidity");
        bic.approve(address(uniswapV2Router), type(uint256).max);
        uniswapV2Router.addLiquidityETH{value: initPoolEthAmount}(
            address(bic),
            initPoolBicAmount,
            0,
            0,
            address(0),
            block.timestamp + 60
        );

        vm.stopPrank();
    }

    function test_FeeToSetterExist_toMakeSureUniswapHasBeenDeployWell() public {
        assertEq(uniswapV2Factory.feeToSetter(), address(54321));
    }

}