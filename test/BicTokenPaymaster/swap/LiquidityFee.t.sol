// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BicTokenPaymasterTestBase.sol";
import {BICErrors} from "../../../src/interfaces/BICErrors.sol";

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

    function test_setLiquidityTreasury() public {
        address newTreasury = vm.addr(0x00001);
        vm.prank(owner);
        bic.setLiquidityTreasury(newTreasury);
        assertEq(newTreasury, bic.liquidityTreasury());
    }

    function test_setLiquidityFee() public {
        uint256 newMinFee = 1000;
        uint256 newMaxFee = 2000;
        vm.startPrank(owner);
        bic.setLiquidityFee(newMinFee, newMaxFee);
        assertEq(newMinFee, bic.minLF());
        assertEq(newMaxFee, bic.maxLF());

        uint256 newMinFee2 = newMaxFee + 1;
        vm.expectRevert("B: invalid values");
        bic.setLiquidityFee(newMinFee2, newMaxFee);

        bic.setLiquidityFee(newMaxFee, newMaxFee);
        assertEq(newMaxFee, bic.getCurrentLF());

        vm.stopPrank();

    }

    function test_setLFReduction() public {
        uint256 newReduction = 1000;
        vm.startPrank(owner);
        bic.setLFReduction(newReduction);
        assertEq(newReduction, bic.LFReduction());
        vm.expectRevert(abi.encodeWithSelector(
            BICErrors.BICLFReduction.selector,
            0
        ));
        bic.setLFReduction(0);
        vm.stopPrank();
    }

    function test_setLFPeriod() public {
        uint256 newPeriod = 1000;
        vm.startPrank(owner);
        bic.setLFPeriod(newPeriod);
        assertEq(newPeriod, bic.LFPeriod());
        vm.expectRevert(abi.encodeWithSelector(
            BICErrors.BICLFPeriod.selector,
            0
        ));
        bic.setLFPeriod(0);
        vm.stopPrank();
    }

    function test_setSwapBackEnabled() public {
        bool swapBackEnabled = bic.swapBackEnabled();
        assertEq(true, swapBackEnabled);
        vm.prank(owner);
        bic.setSwapBackEnabled(false);
        bool swapBackEnabled2 = bic.swapBackEnabled();
        assertEq(false, swapBackEnabled2);
    }

    function test_setMinSwapBackAmount() public {
        uint256 newMinSwapBackAmount = 1000;
        vm.prank(owner);
        bic.setMinSwapBackAmount(newMinSwapBackAmount);
        assertEq(newMinSwapBackAmount, bic.minSwapBackAmount());
    }

    function test_setPool() public {
        vm.prank(owner);
        bic.setPool(bicUniswapPair, true);
        assertEq(true, bic.isPool(bicUniswapPair));
    }

    function test_setBulkExcluded() public {
        address[] memory excluded = new address[](2);
        excluded[0] = vm.addr(0x00001);
        excluded[1] = vm.addr(0x00002);
        vm.prank(owner);
        bic.bulkExcluded(excluded, true);
        assertEq(true, bic.isExcluded(excluded[0]));
        assertEq(true, bic.isExcluded(excluded[1]));
    }

    function test_pause() public {
        assertEq(false, bic.paused());
        vm.prank(owner);
        bic.pause();
        assertEq(true, bic.paused());
        vm.prank(owner);
        bic.transfer(randomUser, 1000);
        vm.startPrank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(
            BICErrors.BICValidateBeforeTransfer.selector,
            randomUser
        ));
        bic.transfer(address(0x123), 1000);
        bic.transfer(address(0x123), 0);
        vm.stopPrank();
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

    function test_setPrePublicWhitelist_failIfAddressLenghtNotValid() public {
        address[] memory addresses = new address[](2);
        uint256[] memory categories = new uint256[](1);
        addresses[0] = vm.addr(0x00001);
        categories[0] = 1;
        addresses[1] = vm.addr(0x00002);
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(
            BICErrors.BICPrePublicWhitelist.selector,
            addresses,
            categories
        ));
        bic.setPrePublicWhitelist(addresses, categories);
        vm.stopPrank();
    }
}