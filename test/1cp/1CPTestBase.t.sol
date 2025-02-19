// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {OneCPDiamond} from "../../src/1cp/1CPDiamond.sol";
import {DiamondCutFacet} from "../../src/1cp/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/1cp/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../../src/1cp/facets/OwnershipFacet.sol";
import {LibDiamond} from "../../src/1cp/libraries/LibDiamond.sol";

contract OneCPTestBase is Test {
    OneCPDiamond public oneCP;
    DiamondCutFacet public diamondCutFacet;
    address public oneCPOwner;

    function setUp() public virtual {
        oneCPOwner = address(1234);
        diamondCutFacet = new DiamondCutFacet();
        oneCP = new OneCPDiamond(oneCPOwner, address(diamondCutFacet));
    }

    function test_deployNew1CP() public {
        oneCP = new OneCPDiamond(oneCPOwner, address(diamondCutFacet));
    }

    function test_deployAndAddOwnershipFacet() public {
        vm.startPrank(oneCPOwner);
        OwnershipFacet ownershipFacet = new OwnershipFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](2);
        functionSelectors[0] = ownershipFacet.owner.selector;
        functionSelectors[1] = ownershipFacet.transferOwnership.selector;

        LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
        cut[0] = LibDiamond.FacetCut({
            facetAddress: address(ownershipFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        // add facet
        DiamondCutFacet(address(oneCP)).diamondCut(cut, address(0), "");
    }
    
    function test_deployAndAddDiamondLoupeFacet() public {
        vm.startPrank(oneCPOwner);
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();

        // make sure that this call fails (without ending the test)
        bool failed = false;
        try DiamondLoupeFacet(address(oneCP)).facetAddresses() returns (
            address[] memory
        ) {} catch {
            failed = true;
        }
        if (!failed) revert("InvalidDiamondSetup");

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](4);
        functionSelectors[0] = diamondLoupeFacet.facets.selector;
        functionSelectors[1] = diamondLoupeFacet.facetFunctionSelectors.selector;
        functionSelectors[2] = diamondLoupeFacet.facetAddresses.selector;
        functionSelectors[3] = diamondLoupeFacet.facetAddress.selector;

        // add facet
        LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
        cut[0] = LibDiamond.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        // add facet
        DiamondCutFacet(address(oneCP)).diamondCut(cut, address(0), "");
    }

    function addFacet(
        OneCPDiamond _diamond,
        address _facet,
        bytes4[] memory _selectors
    ) internal {
        _addFacet(_diamond, _facet, _selectors, address(0), "");
    }

    function addFacet(
        OneCPDiamond _diamond,
        address _facet,
        bytes4[] memory _selectors,
        address _init,
        bytes memory _initCallData
    ) internal {
        _addFacet(_diamond, _facet, _selectors, _init, _initCallData);
    }

    function _addFacet(
        OneCPDiamond _diamond,
        address _facet,
        bytes4[] memory _selectors,
        address _init,
        bytes memory _initCallData
    ) internal {
        vm.startPrank(OwnershipFacet(address(_diamond)).owner());
        LibDiamond.FacetCut[] memory cuts = new LibDiamond.FacetCut[](1);
        cuts[0] = LibDiamond.FacetCut({
            facetAddress: _facet,
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: _selectors
        });

        DiamondCutFacet(address(_diamond)).diamondCut(
            cuts,
            _init,
            _initCallData
        );

        delete cuts;
        vm.stopPrank();
    }
}