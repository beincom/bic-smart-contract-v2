// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OneCPDiamond} from "../src/1cp/1CPDiamond.sol";
import {DiamondCutFacet} from "../src/1cp/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/1cp/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../src/1cp/facets/OwnershipFacet.sol";
import {AccessManagerFacet} from "../src/1cp/facets/AccessManagerFacet.sol";
import {EmergencyPauseFacet} from "../src/1cp/facets/EmergencyPauseFacet.sol";
import {LibDiamond} from "../src/1cp/libraries/LibDiamond.sol";

contract OneCPDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oneCPOwner = vm.envAddress("ONECP_OWNER");
        address pauserWaller = vm.envAddress("PAUSER_WALLET");
        vm.startBroadcast(deployerPrivateKey);

        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        console.log("DiamondCutFacet deployed at:", address(diamondCutFacet));

        OneCPDiamond oneCP = new OneCPDiamond(oneCPOwner, address(diamondCutFacet));
        addOwnershipFacet(address(oneCP));
        addDiamondLoupeFacet(address(oneCP));
        addAccessManagerFacet(address(oneCP));
        addEmergencyPauseFacet(address(oneCP), pauserWaller);

        vm.stopBroadcast();
    }

    function addOwnershipFacet(address oneCP) internal {
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
        DiamondCutFacet(oneCP).diamondCut(cut, address(0), "");
    }

    function addDiamondLoupeFacet(address oneCP) internal {
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
        DiamondCutFacet(oneCP).diamondCut(cut, address(0), "");
    }

    function addAccessManagerFacet(address oneCP) internal {
        AccessManagerFacet accessManagerFacet = new AccessManagerFacet();

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
        DiamondCutFacet(oneCP).diamondCut(cut, address(0), "");
    }

    function addEmergencyPauseFacet(address oneCP, address _pauserWallet) internal {
        EmergencyPauseFacet emergencyPauseFacet = new EmergencyPauseFacet(_pauserWallet);

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
        DiamondCutFacet(oneCP).diamondCut(cut, address(0), "");
    }
}