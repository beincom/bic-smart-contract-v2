// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BicTokenPaymasterTestBase.sol";
import {BicTokenPaymaster_2} from "../../../src/test/BicTokenPaymaster_2.sol";
//import "@account-abstraction/contracts/samples/TokenPaymaster.sol";

contract TestUpgradeAndCall is BicTokenPaymasterTestBase {

    function testUpgradeAndCall() public {
        assertEq(bic.balanceOf(holder1), holder1_init_amount);
        // Deploy a new implementation of BicTokenPaymaster
        address newImplementation = address(new BicTokenPaymaster_2());
        // Upgrade the proxy to the new implementation
        vm.prank(owner);
        bic.upgradeToAndCall(
            newImplementation,
//            abi.encodeWithSignature("initialize(IEntryPoint,address)", (IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789), owner))
            ""
        );
        // Check that the owner of the proxy is the owner of the new implementation
        assertEq(bic.owner(), owner);
        assertEq(bic.balanceOf(holder1), holder1_init_amount);
    }

//    function testUpgradeToAndCall() public {
//        assertEq(bic.owner(), owner);
//
//        address newImplementation = address(new Dummy());
//        vm.prank(owner);
//        bic.upgradeToAndCall(newImplementation, abi.encodeWithSignature("dummy()"));
//        Dummy(address(bic)).dummy();
//    }
}