// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OperationalVault} from "../../src/vault/OperationalVault.sol";
import {DiamondCutFacet} from "../../src/vault/facets/DiamondCutFacet.sol";
import {GasActionsFacet} from "../../src/vault/facets/GasActionsFacet.sol";
import {AccessManagerFacet} from "../../src/vault/facets/AccessManagerFacet.sol";
import {LibDiamond} from "../../src/vault/libraries/LibDiamond.sol";

contract GasActionsFacetDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address operationalVault = vm.envAddress("OPERATIONAL_VAULT");
        address operator = vm.envAddress("OPERATIONAL_VAULT_OPERATOR");

        vm.startBroadcast(deployerPrivateKey);

        // add gas actions facet
        addGasActionsFacet(operationalVault);

        // set access right for operator
        setAccessToSelector(operationalVault, GasActionsFacet.callDepositToPaymaster.selector, operator, true);
        setAccessToSelector(operationalVault, GasActionsFacet.callFundGas.selector, operator, true);

        vm.stopBroadcast();
    }

    function addGasActionsFacet(address operationalVault) internal {
        GasActionsFacet gasActionsFacet = new GasActionsFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](5);
        functionSelectors[0] = gasActionsFacet.getSpendingLimit.selector;
        functionSelectors[1] = gasActionsFacet.setGasBeneficiary.selector;
        functionSelectors[2] = gasActionsFacet.setBeneficiarySpendingLimit.selector;
        functionSelectors[3] = gasActionsFacet.callDepositToPaymaster.selector;
        functionSelectors[4] = gasActionsFacet.callFundGas.selector;

        // prepare diamondCut
        LibDiamond.FacetCut[] memory cuts = new LibDiamond.FacetCut[](1);
        cuts[0] = LibDiamond.FacetCut({
            facetAddress: address(gasActionsFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        // add gas actions facet
        DiamondCutFacet(operationalVault).diamondCut(cuts, address(0), "");
    }

    function setAccessToSelector(
        address operationalVault,
        bytes4 selector,
        address executor,
        bool canAccess
    ) internal {
        AccessManagerFacet(operationalVault).setCanExecute(selector, executor, canAccess);
    }
}