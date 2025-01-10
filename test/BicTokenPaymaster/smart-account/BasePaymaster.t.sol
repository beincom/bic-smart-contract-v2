// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BicTokenPaymasterTestBase.sol";

contract TestBasePaymaster is BicTokenPaymasterTestBase {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_setEntrypoint() public {
        vm.startPrank(owner);
        bic.setEntryPoint(address(0x123));
        assertEq(address(bic.entryPoint()), address(0x123));
        vm.stopPrank();
    }

    function test_stake() public {
        uint256 amount = 1 * 1e18;
        uint32 delay = 86400;
        vm.startPrank(owner);
        vm.deal(owner, amount);
        bic.addStake{value: amount}(delay);
        assertEq(uint256(entrypoint.getDepositInfo(address(bic)).stake), amount);
        assertEq(entrypoint.getDepositInfo(address(bic)).unstakeDelaySec, delay);
        bic.unlockStake();
        vm.warp(block.timestamp + delay + 1);
        bic.withdrawStake(payable(owner));
        assertEq(uint256(entrypoint.getDepositInfo(address(bic)).stake), 0);
        vm.stopPrank();
    }

    function test_deposit() public {
        uint256 amount = 1 * 1e18;
        vm.startPrank(owner);
        vm.deal(owner, amount);
        entrypoint.depositTo{value: amount}(address(bic));
        assertEq(uint256(entrypoint.getDepositInfo(address(bic)).deposit), amount);
        bic.withdrawTo(payable(owner), amount);
        assertEq(uint256(entrypoint.getDepositInfo(address(bic)).deposit), 0);
        vm.stopPrank();
    }
}