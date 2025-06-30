// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OperationalVault} from "../../src/vault/OperationalVault.sol";
import {DiamondCutFacet} from "../../src/vault/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/vault/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../../src/vault/facets/OwnershipFacet.sol";
import {AccessManagerFacet} from "../../src/vault/facets/AccessManagerFacet.sol";
import {EmergencyPauseFacet} from "../../src/vault/facets/EmergencyPauseFacet.sol";
import {LibDiamond} from "../../src/vault/libraries/LibDiamond.sol";

contract OperationalVaultDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address OperationalVaultOwner = vm.envAddress("OPERATIONAL_VAULT_OWNER");
        address pauserWaller = vm.envAddress("OPERATIONAL_VAULT_PAUSER_WALLET");
        vm.startBroadcast(deployerPrivateKey);

        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        console.log("DiamondCutFacet deployed at:", address(diamondCutFacet));

        OperationalVault operationalVault = new OperationalVault(OperationalVaultOwner, address(diamondCutFacet));
        console.log("Operational vault deployed at:", address(operationalVault));
        addOwnershipFacet(address(operationalVault));
        addDiamondLoupeFacet(address(operationalVault));
        addAccessManagerFacet(address(operationalVault));
        addEmergencyPauseFacet(address(operationalVault), pauserWaller);

        vm.stopBroadcast();
    }

    function addOwnershipFacet(address operationalVault) internal {
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
        DiamondCutFacet(operationalVault).diamondCut(cut, address(0), "");
    }

    function addDiamondLoupeFacet(address operationalVault) internal {
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();

        // make sure that this call fails (without ending the test)
        bool failed = false;
        try DiamondLoupeFacet(address(operationalVault)).facetAddresses() returns (
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
        DiamondCutFacet(operationalVault).diamondCut(cut, address(0), "");
    }

    function addAccessManagerFacet(address operationalVault) internal {
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
        DiamondCutFacet(operationalVault).diamondCut(cut, address(0), "");
    }

    function addEmergencyPauseFacet(address operationalVault, address _pauserWallet) internal {
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
        DiamondCutFacet(operationalVault).diamondCut(cut, address(0), "");
    }
}