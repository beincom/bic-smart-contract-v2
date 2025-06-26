// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OperationalVaultTestBase} from "../OperationalVaultTestBase.t.sol";
import {FundManagementFacet} from "../../../src/vault/facets/FundManagementFacet.sol";
import {DiamondCutFacet} from "../../../src/vault/facets/DiamondCutFacet.sol";
import {GasActionsFacet} from "../../../src/vault/facets/GasActionsFacet.sol";
import {EmergencyPauseFacet} from "../../../src/vault/facets/EmergencyPauseFacet.sol";
import {LibDiamond} from "../../../src/vault/libraries/LibDiamond.sol";
import {BicTokenPaymaster} from "../../../src/BicTokenPaymaster.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";

contract GasActionsFacetTest is OperationalVaultTestBase {
    uint256 etherAmount = 1000 ether;
    uint256 depositAmount = 1e24;

    function setUp() public override virtual {
        super.setUp();
        vm.startPrank(operationalVaultOwner);
        GasActionsFacet gasActionsFacet = new GasActionsFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](3);
        functionSelectors[0] = gasActionsFacet.setGasBeneficiary.selector;
        functionSelectors[1] = gasActionsFacet.callDepositToPaymaster.selector;
        functionSelectors[2] = gasActionsFacet.callFundGas.selector;

        // prepare diamondCut
        LibDiamond.FacetCut[] memory cuts = new LibDiamond.FacetCut[](1);
        cuts[0] = LibDiamond.FacetCut({
            facetAddress: address(gasActionsFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        // add donation facet
        DiamondCutFacet(address(operationalVault)).diamondCut(cuts, address(0), "");

        // grant caller access right
        setAccessToSelector(gasActionsFacet.callDepositToPaymaster.selector, operator, true);
        setAccessToSelector(gasActionsFacet.callFundGas.selector, operator, true);

        // set beneficiaries
        GasActionsFacet(address(operationalVault)).setGasBeneficiary(beneficiary, true);
        GasActionsFacet(address(operationalVault)).setGasBeneficiary(address(tBIC), true);

        // deposit token
        tBIC.transfer(address(operationalVault), depositAmount);
        assertEq(depositAmount, tBIC.balanceOf(address(operationalVault)), "balance mismatch");
        
        vm.deal(operationalVaultOwner, etherAmount);

        // deposit ETH
        address(operationalVault).call{value: etherAmount}("");
        assertEq(etherAmount, address(operationalVault).balance, "balance ETH mismatch");
    }

    function test_callFundGas() public {
        vm.startPrank(operator);
        uint256 fundingAmount = 1e20;
        
        // fund token
        assertEq(0, tBIC.balanceOf(address(beneficiary)), "balance mismatch");
        GasActionsFacet(address(operationalVault)).callFundGas(
            address(tBIC),
            beneficiary,
            fundingAmount
        );
        assertEq(fundingAmount, tBIC.balanceOf(address(beneficiary)), "balance mismatch");
        
        // fund ETH
        assertEq(0, beneficiary.balance, "balance ETH mismatch");
        GasActionsFacet(address(operationalVault)).callFundGas(
            address(0),
            beneficiary,
            fundingAmount
        );
        assertEq(fundingAmount, beneficiary.balance, "balance ETH mismatch");
    }

    function test_failed_callFundGas_not_for_beneficiary() public {
        vm.startPrank(operator);
        uint256 fundingAmount = 1e20;
        address newBeneficiary = address(190212);
        // fund token
        assertEq(0, tBIC.balanceOf(address(newBeneficiary)), "balance mismatch");
        vm.expectRevert();
        GasActionsFacet(address(operationalVault)).callFundGas(
            address(tBIC),
            newBeneficiary,
            fundingAmount
        );
        assertEq(0, tBIC.balanceOf(address(newBeneficiary)), "balance mismatch");
        
        // fund ETH
        assertEq(0, newBeneficiary.balance, "balance ETH mismatch");
        vm.expectRevert();
        GasActionsFacet(address(operationalVault)).callFundGas(
            address(0),
            newBeneficiary,
            fundingAmount
        );
        assertEq(0, newBeneficiary.balance, "balance ETH mismatch");
    }

    function test_callDepositToPaymaster() public {
        vm.startPrank(operator);
        uint256 depositETHAmount = 1e20;
        
        // deposit ETH to paymaster
        assertEq(0, entrypoint.balanceOf(address(tBIC)), "deposit balance mismatch");
        assertEq(etherAmount, address(operationalVault).balance, "balance mismatch");
        GasActionsFacet(address(operationalVault)).callDepositToPaymaster(
            address(entrypoint),
            address(tBIC),
            depositETHAmount
        );
        assertEq(depositETHAmount, entrypoint.balanceOf(address(tBIC)), "deposit balance mismatch");
        assertEq(etherAmount - depositETHAmount, address(operationalVault).balance, "balance mismatch");
    }

    function test_failed_callDepositToPaymaster_for_not_beneficiary() public {
        vm.startPrank(operator);
        uint256 depositETHAmount = 1e20;
        address newBeneficiary = address(190212);
        
        // deposit ETH to paymaster
        assertEq(0, entrypoint.balanceOf(address(newBeneficiary)), "deposit balance mismatch");
        assertEq(etherAmount, address(operationalVault).balance, "balance mismatch");
        vm.expectRevert();
        GasActionsFacet(address(operationalVault)).callDepositToPaymaster(
            address(entrypoint),
            newBeneficiary,
            depositETHAmount
        );
        assertEq(etherAmount, address(operationalVault).balance, "balance mismatch");
    }

    function test_pause_emergency() public {
        vm.startPrank(operationalVaultOwner);
       
        // pause operational vault
        EmergencyPauseFacet(payable(address(operationalVault))).pauseDiamond();

        vm.startPrank(operator);
        uint256 fundingAmount = 1e20;
        
        // fund token
        assertEq(0, tBIC.balanceOf(address(beneficiary)), "balance mismatch");
        vm.expectRevert();
        GasActionsFacet(address(operationalVault)).callFundGas(
            address(tBIC),
            beneficiary,
            fundingAmount
        );
        
        // deposit ETH to paymaster
        uint256 depositETHAmount = 1e20;
        assertEq(0, entrypoint.balanceOf(address(tBIC)), "deposit balance mismatch");
        assertEq(etherAmount, address(operationalVault).balance, "balance mismatch");
        vm.expectRevert();
        GasActionsFacet(address(operationalVault)).callDepositToPaymaster(
            address(entrypoint),
            address(tBIC),
            depositETHAmount
        );
    }

    function test_remove_access_right() public {
        vm.startPrank(operationalVaultOwner);
       
        // remove access right
        setAccessToSelector(GasActionsFacet.callDepositToPaymaster.selector, operator, false);

        vm.startPrank(operator);
        uint256 fundingAmount = 1e20;
        
        // fund token
        assertEq(0, tBIC.balanceOf(address(beneficiary)), "balance mismatch");
        GasActionsFacet(address(operationalVault)).callFundGas(
            address(tBIC),
            beneficiary,
            fundingAmount
        );
        
        // deposit ETH to paymaster
        uint256 depositETHAmount = 1e20;
        assertEq(0, entrypoint.balanceOf(address(tBIC)), "deposit balance mismatch");
        assertEq(etherAmount, address(operationalVault).balance, "balance mismatch");
        vm.expectRevert();
        GasActionsFacet(address(operationalVault)).callDepositToPaymaster(
            address(entrypoint),
            address(tBIC),
            depositETHAmount
        );
    }
}