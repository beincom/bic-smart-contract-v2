// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BicTokenPaymasterTestBase.sol";
import {BicTokenPaymasterV2} from "../../contracts/BicTokenPaymasterV2.sol";

contract TestUpgradeAndCall is BicTokenPaymasterTestBase {
    function testUpgradeAndCall() public {
        // Initial balance check
        console.log("Testing initial balance");
        assertEq(bic.balanceOf(holder1), holder1_init_amount);

        // Deploy a new implementation of BicTokenPaymaster
        address newImplementation = address(new BicTokenPaymasterV2());

        vm.startPrank(owner);

        console.log("Testing blocklist before upgrade");
        bic.addToBlockedList(holder1);
        bic.upgradeToAndCall(newImplementation, "");
    }

    function testUpgradeOwnership() public {
        address newImplementation = address(new BicTokenPaymasterV2());
        BicTokenPaymasterV2 bicV2 = BicTokenPaymasterV2(address(bic));

        vm.startPrank(owner);
        bic.upgradeToAndCall(newImplementation, "");
        assertEq(bicV2.owner(), owner);
        vm.stopPrank();
    }

    function testUpgradeBlocklist() public {
        address newImplementation = address(new BicTokenPaymasterV2());
        BicTokenPaymasterV2 bicV2 = BicTokenPaymasterV2(address(bic));

        vm.startPrank(owner);
        bic.addToBlockedList(holder1);
        bic.upgradeToAndCall(newImplementation, "");
        assertEq(bicV2.isBlocked(holder1), true);
        vm.stopPrank();
    }

    function testUpgradeFee() public {
        address newImplementation = address(new BicTokenPaymasterV2());
        BicTokenPaymasterV2 bicV2 = BicTokenPaymasterV2(address(bic));

        vm.startPrank(owner);
        bic.upgradeToAndCall(newImplementation, "");
        bicV2.setFee(2000);
        assertEq(bicV2.getFee(), 2000);
        vm.stopPrank();
    }

    function testPauseShouldRevertAfterUpgrade() public {
        // Deploy a new implementation of BicTokenPaymaster
        address newImplementation = address(new BicTokenPaymasterV2());
        BicTokenPaymasterV2 bicV2 = BicTokenPaymasterV2(address(bic));

        vm.startPrank(owner);
        bic.upgradeToAndCall(newImplementation, "");

        // Test that pause() reverts
        vm.expectRevert();
        bicV2.pause();

        vm.stopPrank();
    }
}
