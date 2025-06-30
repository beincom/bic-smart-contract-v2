// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OperationalVault} from "../../src/vault/OperationalVault.sol";
import {DiamondCutFacet} from "../../src/vault/facets/DiamondCutFacet.sol";
import {GasActionsFacet} from "../../src/vault/facets/GasActionsFacet.sol";
import {AccessManagerFacet} from "../../src/vault/facets/AccessManagerFacet.sol";
import {LibDiamond} from "../../src/vault/libraries/LibDiamond.sol";

contract SetBeneficiaryAndSpendingLimitScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address operationalVault = vm.envAddress("OPERATIONAL_VAULT");
        address beneficiary = vm.envAddress("OPERATIONAL_VAULT_BENEFICIARY");
        address assetAddress = vm.envAddress("OPERATIONAL_VAULT_SPENDING_ASSET_ADDRESS");
        uint256 spendingLimit = vm.envUint("OPERATIONAL_VAULT_SPENDING_LIMIT");
        uint256 period = vm.envUint("OPERATIONAL_VAULT_SPENDING_PERIOD"); 

        vm.startBroadcast(deployerPrivateKey);

        // set beneficiary
        GasActionsFacet(address(operationalVault)).setGasBeneficiary(beneficiary, true);
        // set spending limits of beneficiaries
        GasActionsFacet(address(operationalVault)).setBeneficiarySpendingLimit(
            beneficiary,
            assetAddress,
            spendingLimit,
            period
        );

        vm.stopBroadcast();
    }
}