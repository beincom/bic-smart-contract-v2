// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BicTokenPaymasterTestBase.sol";
//import "@account-abstraction/contracts/samples/TokenPaymaster.sol";

contract TestUpgradeAndCall is BicTokenPaymasterTestBase {

//    function testUpgradeAndCall() public {
//        assertEq(bic.balanceOf(holder1), holder1_init_amount);
//        // Deploy a new implementation of BicTokenPaymaster
//        TokenPaymaster newImplementation = new TokenPaymaster();
//        // Upgrade the proxy to the new implementation
//        vm.prank(owner);
//        bic.upgradeToAndCall(newImplementation, abi.encodeWithSignature("initialize(address)", owner));
//        // Check that the owner of the proxy is the owner of the new implementation
//        assertEq(bic.owner(), owner);
//        assertEq(bic.balanceOf(holder1), holder1_init_amount);
//    }

    function testUpgradeToAndCall() public {
        assertEq(bic.owner(), owner);

        address newImplementation = address(new Dummy());
        vm.prank(owner);
        bic.upgradeToAndCall(newImplementation, abi.encodeWithSignature("dummy()"));
        Dummy(address(bic)).dummy();
    }
}

contract Dummy is UUPSUpgradeable {
    event Done();

    function dummy() public {
        emit Done();
    }

    function _authorizeUpgrade(address newImplementation) internal override {}
}