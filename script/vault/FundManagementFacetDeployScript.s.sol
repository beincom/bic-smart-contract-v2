// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OperationalVault} from "../../src/vault/OperationalVault.sol";
import {DiamondCutFacet} from "../../src/vault/facets/DiamondCutFacet.sol";
import {FundManagementFacet} from "../../src/vault/facets/FundManagementFacet.sol";
import {AccessManagerFacet} from "../../src/vault/facets/AccessManagerFacet.sol";
import {LibDiamond} from "../../src/vault/libraries/LibDiamond.sol";

contract FundManagementFacetDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address operationalVault = vm.envAddress("OPERATIONAL_VAULT");

        vm.startBroadcast(deployerPrivateKey);

        // add fund management facet
        addFundManagementFacet(operationalVault);

        vm.stopBroadcast();
    }

    function addFundManagementFacet(address operationalVault) internal {
        FundManagementFacet fundManagementFacet = new FundManagementFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](2);
        functionSelectors[0] = fundManagementFacet.depositAsset.selector;
        functionSelectors[1] = fundManagementFacet.withdrawAsset.selector;
        
        // prepare diamondCut
        LibDiamond.FacetCut[] memory cuts = new LibDiamond.FacetCut[](1);
        cuts[0] = LibDiamond.FacetCut({
            facetAddress: address(fundManagementFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        // add fund management facet
        DiamondCutFacet(operationalVault).diamondCut(cuts, address(0), "");
    }
}