// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BicTokenPaymasterTestBase} from "../BicTokenPaymasterTestBase.sol";

contract BlockTest is BicTokenPaymasterTestBase {
    address public badAddress = vm.addr(0xbad);

    function setUp() public override {
        super.setUp();
    }

    function test_block() public {
        assertEq(isBlocked(badAddress), false, "badAddress should not be blocked");
        vm.prank(owner);
        bic.blockAddress(badAddress, true);
        assertEq(isBlocked(badAddress), true, "badAddress should be blocked");
    }
}