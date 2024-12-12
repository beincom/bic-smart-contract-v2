// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BicTokenPaymasterTestBase.sol";
import {BicTokenPaymaster_2} from "../../contracts/BicTokenPaymaster_2.sol";

contract TestUpgradeAndCall is BicTokenPaymasterTestBase {

    function testUpgradeAndCall() public {
        assertEq(bic.balanceOf(holder1), holder1_init_amount);
        // Deploy a new implementation of BicTokenPaymaster
        address newImplementation = address(new BicTokenPaymaster_2());
        // Upgrade the proxy to the new implementation
        vm.prank(owner);
        bic.upgradeToAndCall(
            newImplementation,
            ""
        );
        // Check that the owner of the proxy is the owner of the new implementation
        assertEq(bic.owner(), owner);
        assertEq(bic.balanceOf(holder1), holder1_init_amount);
    }

}