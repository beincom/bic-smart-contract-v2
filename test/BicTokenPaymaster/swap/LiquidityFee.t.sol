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

    function test_setLiquidityTreasuryUpdated() public {
        address newTreasury = vm.addr(0x00001);
        vm.prank(owner);
        bic.setLiquidityTreasury(newTreasury);
        assertEq(newTreasury, getLiquidityTreasury());
    }

    function test_setLiquidityFeeUpdated() public {
        uint256 newMinFee = 1000;
        uint256 newMaxFee = 2000;
        vm.prank(owner);
        bic.setLiquidityFee(newMinFee, newMaxFee);
        assertEq(newMinFee, getMinLF());
        assertEq(newMaxFee, getMaxLF());
    }

    function test_setLFReduction() public {
        uint256 newReduction = 1000;
        vm.prank(owner);
        bic.setLFReduction(newReduction);
        assertEq(newReduction, getLFReduction());
    }

    function test_setLFPeriod() public {
        uint256 newPeriod = 1000;
        vm.prank(owner);
        bic.setLFPeriod(newPeriod);
        assertEq(newPeriod, getLFPeriod());
    }

    function test_setSwapBackEnabled() public {
        (, , bool swapBackEnabled, ) = getRouterNBoolFlags();
        assertEq(true, swapBackEnabled);
        vm.prank(owner);
        bic.setSwapBackEnabled(false);
        (,, bool swapBackEnabled2,) = getRouterNBoolFlags();
        assertEq(false, swapBackEnabled2);
    }

    function test_setMinSwapBackAmount() public {
        uint256 newMinSwapBackAmount = 1000;
        vm.prank(owner);
        bic.setMinSwapBackAmount(newMinSwapBackAmount);
        assertEq(newMinSwapBackAmount, getMinSwapBackAmount());
    }

    function test_setLiquidityTreasury() public {
        address newTreasury = vm.addr(0x00001);
        vm.prank(owner);
        bic.setLiquidityTreasury(newTreasury);
        assertEq(newTreasury, getLiquidityTreasury());
    }

    function test_setPool() public {
        vm.prank(owner);
        bic.setPool(bicUniswapPair, true);
        assertEq(true, isPool(bicUniswapPair));
    }

    function test_setBulkExcluded() public {
        address[] memory excluded = new address[](2);
        excluded[0] = vm.addr(0x00001);
        excluded[1] = vm.addr(0x00002);
        vm.prank(owner);
        bic.bulkExcluded(excluded, true);
        assertEq(true, isExcluded(excluded[0]));
        assertEq(true, isExcluded(excluded[1]));
    }

    function test_pause() public {
        assertEq(false, bic.paused());
        vm.prank(owner);
        bic.pause();
        assertEq(true, bic.paused());
        vm.prank(owner);
        bic.unpause();
        assertEq(false, bic.paused());
    }

    function test_withdrawStuckTokens() public {
        address toAddress = vm.addr(0x10001);
        uint256 amount = 1000;
        vm.prank(owner);
        bic.transfer(address(bic), amount);
        assertEq(amount, bic.balanceOf(address(bic)));
        vm.deal(address(bic), amount);
        assertEq(amount, address(bic).balance);
        vm.prank(owner);
        bic.withdrawStuckToken(address(bic),toAddress,amount);
        assertEq(amount, bic.balanceOf(toAddress));
        vm.prank(owner);
        bic.withdrawStuckToken(address(0),toAddress,amount);
        assertEq(amount, address(toAddress).balance);
    }
}