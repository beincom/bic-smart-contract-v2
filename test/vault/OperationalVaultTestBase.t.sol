// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {OperationalVault} from "../../src/vault/OperationalVault.sol";
import {DiamondCutFacet} from "../../src/vault/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/vault/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../../src/vault/facets/OwnershipFacet.sol";
import {AccessManagerFacet} from "../../src/vault/facets/AccessManagerFacet.sol";
import {EmergencyPauseFacet} from "../../src/vault/facets/EmergencyPauseFacet.sol";
import {LibDiamond} from "../../src/vault/libraries/LibDiamond.sol";
import {BicTokenPaymaster} from "../../src/BicTokenPaymaster.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";

contract OperationalVaultTestBase is Test {
    OperationalVault public operationalVault;
    DiamondCutFacet public diamondCutFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public ownershipFacet;
    AccessManagerFacet public accessManagerFacet;
    EmergencyPauseFacet public emergencyPauseFacet;

    address public operationalVaultOwner;
    address public pauserWallet;
    
    BicTokenPaymaster public tBIC;
    EntryPoint public entrypoint;
    address public beneficiary;
    address public operator;
    address[] signers = [operationalVaultOwner];

    function setUp() public virtual {
        operationalVaultOwner = address(1234);
        pauserWallet = address(123455);
        operator = address(123123);
        beneficiary = address(123456);

        vm.startPrank(operationalVaultOwner);
        diamondCutFacet = new DiamondCutFacet();
        operationalVault = new OperationalVault(operationalVaultOwner, address(diamondCutFacet));
        
        entrypoint = new EntryPoint();
        tBIC = new BicTokenPaymaster(address(entrypoint), operationalVaultOwner, signers);
        
        addOwnershipFacet();
        addDiamondLoupeFacet();
        addAccessManagerFacet();
        addEmergencyPauseFacet(pauserWallet);
    }

    function addOwnershipFacet() internal {
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
        DiamondCutFacet(address(operationalVault)).diamondCut(cut, address(0), "");
    }
    
    function addDiamondLoupeFacet() internal {
        diamondLoupeFacet = new DiamondLoupeFacet();

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
        DiamondCutFacet(address(operationalVault)).diamondCut(cut, address(0), "");
    }

    function addAccessManagerFacet() internal {
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
        DiamondCutFacet(address(operationalVault)).diamondCut(cut, address(0), "");
    }

    function setAccessToSelector(
        bytes4 selector,
        address executor,
        bool canAccess
    ) internal {
        AccessManagerFacet(address(operationalVault)).setCanExecute(selector, executor, canAccess);
    }

    function addEmergencyPauseFacet(address _pauserWallet) internal {
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
        DiamondCutFacet(address(operationalVault)).diamondCut(cut, address(0), "");
    }
}