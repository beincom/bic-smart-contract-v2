// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OneCPTestBase} from "../1CPTestBase.t.sol";
import {DiamondCutFacet} from "../../../src/1cp/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../../src/1cp/facets/DiamondLoupeFacet.sol";
import {LibDiamond} from "../../../src/1cp/libraries/LibDiamond.sol";

contract DiamondLoupeFacetTest is OneCPTestBase {
    function test_checkSelectorToFacet() public {
        address _diamondLoupeFacet = DiamondLoupeFacet(address(oneCP)).facetAddress(diamondLoupeFacet.facetAddress.selector);
        assertEq(_diamondLoupeFacet, address(diamondLoupeFacet), "facet mismatch");
    }

    function test_replaceSelectorFunction() public {
        vm.startPrank(oneCPOwner);

        // prepare remove function selectors
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = diamondLoupeFacet.supportsInterface.selector;

        LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
        cut[0] = LibDiamond.FacetCut({
            facetAddress: address(ownershipFacet),
            action: LibDiamond.FacetCutAction.Replace,
            functionSelectors: functionSelectors
        });

        // replace selectors
        DiamondCutFacet(address(oneCP)).diamondCut(cut, address(0), "");
        address supportsInterfaceInFacet = DiamondLoupeFacet(address(oneCP)).facetAddress(functionSelectors[0]);
        assertNotEq(supportsInterfaceInFacet, address(diamondLoupeFacet), "selector already replace to new facet");
    }
}