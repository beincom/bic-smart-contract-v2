// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BicTokenPaymasterTestBase.sol";
import {BicTokenPaymasterV2} from "../../contracts/BicTokenPaymaster_2.sol";

contract TestUpgradeAndCall is BicTokenPaymasterTestBase {
    function testUpgradeAndCall() public {
        assertEq(bic.balanceOf(holder1), holder1_init_amount);
        // Deploy a new implementation of BicTokenPaymaster
        // address newImplementation = address(new BicTokenPaymasterV2());

        // vm.startPrank(owner);
        // vm.stopPrank();

        // bic.upgradeToAndCall(newImplementation, "");
    }

    // function testUpgradeOwnership() public {
    //     address newImplementation = address(new BicTokenPaymasterV2());
    //     BicTokenPaymasterV2 bicV2 = BicTokenPaymasterV2(payable(address(bic)));

    //     vm.startPrank(owner);
    //     bic.upgradeToAndCall(newImplementation, "");
    //     assertEq(bicV2.owner(), owner);
    //     vm.stopPrank();
    // }
}
