// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {OneCPDiamond} from "../../src/1cp/1CPDiamond.sol";
import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../../src/diamond/facets/OwnershipFacet.sol";
import {AccessManagerFacet} from "../../src/diamond/facets/AccessManagerFacet.sol";
import {EmergencyPauseFacet} from "../../src/1cp/facets/EmergencyPauseFacet.sol";
import {LibDiamond} from "../../src/diamond/libraries/LibDiamond.sol";

contract OneCPTestBase is Test {
    OneCPDiamond public oneCP;
    DiamondCutFacet public diamondCutFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public ownershipFacet;
    AccessManagerFacet public accessManagerFacet;
    EmergencyPauseFacet public emergencyPauseFacet;
    address public oneCPOwner;
    address public pauserWallet;

    function setUp() public virtual {
        oneCPOwner = address(1234);
        pauserWallet = address(123455);
        diamondCutFacet = new DiamondCutFacet();
        oneCP = new OneCPDiamond(oneCPOwner, address(diamondCutFacet));
        addOwnershipFacet();
        addDiamondLoupeFacet();
        addAccessManagerFacet();
        addEmergencyPauseFacet(pauserWallet);
    }

    function addOwnershipFacet() internal {
        vm.startPrank(oneCPOwner);
        ownershipFacet = new OwnershipFacet();

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
    
    function addDiamondLoupeFacet() internal {
        vm.startPrank(oneCPOwner);
        diamondLoupeFacet = new DiamondLoupeFacet();

        // make sure that this call fails (without ending the test)
        bool failed = false;
        try DiamondLoupeFacet(address(oneCP)).facetAddresses() returns (
            address[] memory
        ) {} catch {
            failed = true;
        }
        if (!failed) revert("InvalidDiamondSetup");

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](5);
        functionSelectors[0] = diamondLoupeFacet.facets.selector;
        functionSelectors[1] = diamondLoupeFacet.facetFunctionSelectors.selector;
        functionSelectors[2] = diamondLoupeFacet.facetAddresses.selector;
        functionSelectors[3] = diamondLoupeFacet.facetAddress.selector;
        functionSelectors[4] = diamondLoupeFacet.supportsInterface.selector;

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

    function addAccessManagerFacet() internal {
        vm.startPrank(oneCPOwner);
        accessManagerFacet = new AccessManagerFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](2);
        functionSelectors[0] = accessManagerFacet.setCanExecute.selector;
        functionSelectors[1] = accessManagerFacet.addressCanExecuteMethod.selector;

        LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
        cut[0] = LibDiamond.FacetCut({
            facetAddress: address(accessManagerFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        // add facet
        DiamondCutFacet(address(oneCP)).diamondCut(cut, address(0), "");
    }

    function setAccessToSelector(
        bytes4 selector,
        address executor,
        bool canAccess
    ) internal {
        AccessManagerFacet(address(oneCP)).setCanExecute(selector, executor, canAccess);
    }

    function addEmergencyPauseFacet(address _pauserWallet) internal {
        vm.startPrank(oneCPOwner);
        emergencyPauseFacet = new EmergencyPauseFacet(_pauserWallet);

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](3);
        functionSelectors[0] = emergencyPauseFacet.removeFacet.selector;
        functionSelectors[1] = emergencyPauseFacet.pauseDiamond.selector;
        functionSelectors[2] = emergencyPauseFacet.unpauseDiamond.selector;

        LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
        cut[0] = LibDiamond.FacetCut({
            facetAddress: address(emergencyPauseFacet),
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