// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OperationalVaultTestBase} from "../OperationalVaultTestBase.t.sol";
import {DiamondCutFacet} from "../../../src/vault/facets/DiamondCutFacet.sol";
import {FundManagementFacet} from "../../../src/vault/facets/FundManagementFacet.sol";
import {EmergencyPauseFacet} from "../../../src/vault/facets/EmergencyPauseFacet.sol";
import {LibDiamond} from "../../../src/vault/libraries/LibDiamond.sol";

contract FundManagementFacetTest is OperationalVaultTestBase {
    function setUp() public override virtual {
        super.setUp();
        vm.startPrank(operationalVaultOwner);
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

        // add donation facet
        DiamondCutFacet(address(operationalVault)).diamondCut(cuts, address(0), "");
    }

    function test_depositAsset() public {
        vm.startPrank(operationalVaultOwner);
        tBIC.approve(address(operationalVault), type(uint256).max);
        uint256 depositAmount = 1e24;
        // deposit token
        FundManagementFacet(address(operationalVault)).depositAsset(
            address(tBIC),
            depositAmount
        );
        assertEq(depositAmount, tBIC.balanceOf(address(operationalVault)), "balance mismatch");
        
        // transfer token
        uint256 mintAmount = 1e24;
        tBIC.transfer(beneficiary, mintAmount);
        vm.startPrank(beneficiary);
        tBIC.transfer(address(operationalVault), mintAmount);
        assertEq(depositAmount + mintAmount, tBIC.balanceOf(address(operationalVault)), "balance mismatch");

        uint256 etherAmount = 1000 ether;
        vm.deal(operationalVaultOwner, etherAmount);
        vm.deal(beneficiary, etherAmount);

        // deposit ETH
        vm.startPrank(operationalVaultOwner);
        FundManagementFacet(address(operationalVault)).depositAsset{value: etherAmount}(
            address(0),
            etherAmount
        );
        assertEq(etherAmount, address(operationalVault).balance, "balance ETH mismatch");
        
        // transfer ETH
        vm.startPrank(beneficiary);
        address(operationalVault).call{value: etherAmount}("");
        assertEq(2 * etherAmount, address(operationalVault).balance, "balance ETH mismatch");
    }

    function test_withdrawAsset() public {
        vm.startPrank(operationalVaultOwner);
        tBIC.approve(address(operationalVault), type(uint256).max);
        uint256 depositAmount = 1e24;
        // deposit token
        FundManagementFacet(address(operationalVault)).depositAsset(
            address(tBIC),
            depositAmount
        );
        assertEq(depositAmount, tBIC.balanceOf(address(operationalVault)), "balance mismatch");
        
        // withdraw token
        assertEq(0, tBIC.balanceOf(address(beneficiary)), "balance mismatch");
        FundManagementFacet(address(operationalVault)).withdrawAsset(
            address(tBIC),
            beneficiary,
            depositAmount
        );
        assertEq(depositAmount, tBIC.balanceOf(address(beneficiary)), "balance mismatch");

        uint256 etherAmount = 1000 ether;
        vm.deal(operationalVaultOwner, etherAmount);

        // deposit ETH
        vm.startPrank(operationalVaultOwner);
        FundManagementFacet(address(operationalVault)).depositAsset{value: etherAmount}(
            address(0),
            etherAmount
        );
        assertEq(etherAmount, address(operationalVault).balance, "balance ETH mismatch");
        
        // withdraw ETH
        assertEq(0, beneficiary.balance, "balance mismatch");
        FundManagementFacet(address(operationalVault)).withdrawAsset(
            address(0),
            beneficiary,
            etherAmount
        );
        assertEq(etherAmount, beneficiary.balance, "balance mismatch");
    }

    function test_failed_withdrawAsset_by_unauthorized() public {
        vm.startPrank(operationalVaultOwner);
        uint256 withdrawAmount = 1e24;
        tBIC.transfer(beneficiary, withdrawAmount);
        vm.startPrank(beneficiary);
        tBIC.transfer(address(operationalVault), withdrawAmount);
        assertEq(withdrawAmount, tBIC.balanceOf(address(operationalVault)), "balance mismatch");

        vm.expectRevert();
        FundManagementFacet(address(operationalVault)).withdrawAsset(
            address(tBIC),
            beneficiary,
            withdrawAmount
        );
    }

    function test_pause_emergency() public {
        vm.startPrank(operationalVaultOwner);
        tBIC.approve(address(operationalVault), type(uint256).max);
        uint256 depositAmount = 1e24;
        // deposit token
        FundManagementFacet(address(operationalVault)).depositAsset(
            address(tBIC),
            depositAmount
        );
        assertEq(depositAmount, tBIC.balanceOf(address(operationalVault)), "balance mismatch");
        
        // pause operational vault
        EmergencyPauseFacet(payable(address(operationalVault))).pauseDiamond();

        // withdraw token
        assertEq(0, tBIC.balanceOf(address(beneficiary)), "balance mismatch");
        vm.expectRevert();
        FundManagementFacet(address(operationalVault)).withdrawAsset(
            address(tBIC),
            beneficiary,
            depositAmount
        );
    }
}