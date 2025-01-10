// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {BicTokenPaymasterTestBase} from "../BicTokenPaymasterTestBase.sol";

contract BlockTest is BicTokenPaymasterTestBase {
    address public badAddress = vm.addr(0xbad);

    function setUp() public override {
        super.setUp();
    }

    function test_block() public {
        assertEq(bic.isBlocked(badAddress), false, "badAddress should not be blocked");
        vm.prank(owner);
        bic.blockAddress(badAddress, true);
        assertEq(bic.isBlocked(badAddress), true, "badAddress should be blocked");
    }
}