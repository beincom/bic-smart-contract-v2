// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OneCPTestBase} from "../1CPTestBase.t.sol";
import {DiamondCutFacet} from "../../../src/1cp/facets/DiamondCutFacet.sol";
import {AccessManagerFacet} from "../../../src/1cp/facets/AccessManagerFacet.sol";
import {LibDiamond} from "../../../src/1cp/libraries/LibDiamond.sol";

contract AccessManagerTest is OneCPTestBase {
    address public executor;
    function setUp() public override virtual {
        super.setUp();
        vm.startPrank(oneCPOwner);
        executor = address(1233);
    }

    function test_addAccess() public {
        setAccessToSelector(accessManagerFacet.setCanExecute.selector, executor, true);
    }

    function test_checkAccessOfSelector() public {
        setAccessToSelector(accessManagerFacet.setCanExecute.selector, executor, true);
        bool canAccess = AccessManagerFacet(address(oneCP)).addressCanExecuteMethod(accessManagerFacet.setCanExecute.selector, executor);
        assertEq(canAccess, true, "cannot access");
    }
}