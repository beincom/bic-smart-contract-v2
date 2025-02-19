// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OneCPTestBase} from "../1CPTestBase.t.sol";
import {DiamondCutFacet} from "../../../src/1cp/facets/DiamondCutFacet.sol";
import {AccessManagerFacet} from "../../../src/1cp/facets/AccessManagerFacet.sol";
import {LibDiamond} from "../../../src/1cp/libraries/LibDiamond.sol";

contract AccessManagerTest is OneCPTestBase {
    function setUp() public override virtual {
        super.setUp();
        vm.startPrank(oneCPOwner);
        AccessManagerFacet accessManagerFacet = new AccessManagerFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](2);
        functionSelectors[0] = accessManagerFacet.setCanExecute.selector;
        functionSelectors[1] = accessManagerFacet.addressCanExecuteMethod.selector;

        // prepare diamondCut
        LibDiamond.FacetCut[] memory cuts = new LibDiamond.FacetCut[](1);
        cuts[0] = LibDiamond.FacetCut({
            facetAddress: address(accessManagerFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        DiamondCutFacet(address(oneCP)).diamondCut(cuts, address(0), "");
    }

    function setAccessToSelector(
        bytes4 selector,
        address executor,
        bool canAccess
    ) internal {
        AccessManagerFacet(address(oneCP)).setCanExecute(selector, executor, canAccess);
    }
}