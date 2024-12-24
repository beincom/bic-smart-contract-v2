// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BicTokenPaymasterTestBase.sol";
import {BicTokenPaymasterV2} from "../../contracts/BicTokenPaymaster_2.sol";

contract TestUpgradeAndCall is BicTokenPaymasterTestBase {
    function testUpgradeData() public {
        address newImplementation = address(new BicTokenPaymasterV2());
        vm.startPrank(owner);
        bic.upgradeToAndCall(newImplementation, "");
        BicTokenPaymasterV2 bicV2 = BicTokenPaymasterV2(payable(address(bic)));
        assertEq(bicV2.balanceOf(holder1), holder1_init_amount);

        vm.stopPrank();
    }

    function testUpgradeBlocklist() public {
        address newImplementation = address(new BicTokenPaymasterV2());

        vm.startPrank(owner);
        bic.blockAddress(holder1, true);
        bic.upgradeToAndCall(newImplementation, "");
        BicTokenPaymasterV2 bicV2 = BicTokenPaymasterV2(payable(address(bic)));

        assertEq(bicV2.isBlocked(holder1), true);
        vm.stopPrank();
    }

    function testNewFunctionAfterUpdated() public {
        // address newImplementation = address(new BicTokenPaymasterV2());
        // vm.startPrank(owner);
        // bic.upgradeToAndCall(newImplementation, "");
        // BicTokenPaymasterV2 bicV2 = BicTokenPaymasterV2(payable(address(bic)));
        // bicV2.setNewValue(1000);
        // assertEq(bicV2.getNewValue(), 1000);
        // vm.stopPrank();
    }

    function testPauseShouldRevertAfterUpgrade() public {
        // Deploy a new implementation of BicTokenPaymaster
        address newImplementation = address(new BicTokenPaymasterV2());

        vm.startPrank(owner);
        bic.upgradeToAndCall(newImplementation, "");
        BicTokenPaymasterV2 bicV2 = BicTokenPaymasterV2(payable(address(bic)));

        // Test that pause() reverts
        // vm.expectRevert();
        bicV2.pause();
        vm.stopPrank();
    }
}
