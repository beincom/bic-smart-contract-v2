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
    uint256 depositETHAmount = 1000 ether;
    uint256 depositTokenAmount = 1e24;
    uint256 spendingLimit = 1e20;
    uint256 period = 15;

    function setUp() public override virtual {
        super.setUp();
        vm.startPrank(operationalVaultOwner);
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

        // add donation facet
        DiamondCutFacet(address(operationalVault)).diamondCut(cuts, address(0), "");

        // grant caller access right
        setAccessToSelector(gasActionsFacet.callDepositToPaymaster.selector, operator, true);
        setAccessToSelector(gasActionsFacet.callFundGas.selector, operator, true);

        // set beneficiaries
        GasActionsFacet(address(operationalVault)).setGasBeneficiary(beneficiary, true);
        GasActionsFacet(address(operationalVault)).setGasBeneficiary(address(tBIC), true);

        // set spending limits of beneficiaries
        GasActionsFacet(address(operationalVault)).setBeneficiarySpendingLimit(
            beneficiary,
            address(tBIC),
            spendingLimit,
            period
        );
        GasActionsFacet(address(operationalVault)).setBeneficiarySpendingLimit(
            beneficiary,
            address(0),
            spendingLimit,
            period
        );

        GasActionsFacet(address(operationalVault)).setBeneficiarySpendingLimit(
            address(tBIC),
            address(0),
            spendingLimit,
            period
        );

        // deposit token
        tBIC.transfer(address(operationalVault), depositTokenAmount);
        assertEq(depositTokenAmount, tBIC.balanceOf(address(operationalVault)), "balance mismatch");
        
        vm.deal(operationalVaultOwner, depositETHAmount);

        // deposit ETH
        address(operationalVault).call{value: depositETHAmount}("");
        assertEq(depositETHAmount, address(operationalVault).balance, "balance ETH mismatch");
    }

    function test_check_spendingLimit() public view {
        (
            uint256 periodSpendingToken,
            uint256 maxSpendingToken,
            uint256 currentUsageToken,
            uint256 lastSpendToken
        ) = GasActionsFacet(address(operationalVault)).getSpendingLimit(beneficiary, address(tBIC));

        assertEq(period, periodSpendingToken);
        assertEq(spendingLimit, maxSpendingToken);
        assertEq(0, currentUsageToken);
        assertEq(0, lastSpendToken);
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
        assertEq(depositTokenAmount - fundingAmount, tBIC.balanceOf(address(operationalVault)), "balance mismatch");
        
        // fund ETH
        assertEq(0, beneficiary.balance, "balance ETH mismatch");
        GasActionsFacet(address(operationalVault)).callFundGas(
            address(0),
            beneficiary,
            fundingAmount
        );
        assertEq(fundingAmount, beneficiary.balance, "balance ETH mismatch");
        assertEq(depositETHAmount - fundingAmount, address(operationalVault).balance, "balance ETH mismatch");
    }

    function test_callFundGas_exceed_spendingLimit() public {
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
        assertEq(depositTokenAmount - fundingAmount, tBIC.balanceOf(address(operationalVault)), "balance mismatch");

        vm.expectRevert();
        GasActionsFacet(address(operationalVault)).callFundGas(
            address(tBIC),
            beneficiary,
            fundingAmount
        );
        
        // fund ETH
        assertEq(0, beneficiary.balance, "balance ETH mismatch");
        GasActionsFacet(address(operationalVault)).callFundGas(
            address(0),
            beneficiary,
            fundingAmount
        );
        assertEq(fundingAmount, beneficiary.balance, "balance ETH mismatch");
        assertEq(depositETHAmount - fundingAmount, address(operationalVault).balance, "balance ETH mismatch");

        vm.expectRevert();
        GasActionsFacet(address(operationalVault)).callFundGas(
            address(0),
            beneficiary,
            fundingAmount
        );
    }

    function test_callFundGas_within_spendingLimit() public {
        vm.startPrank(operator);
        uint256 fundingAmount = 1e19;
        uint256 loops = 10;
        
        // fund token
        assertEq(0, tBIC.balanceOf(address(beneficiary)), "balance mismatch");
        
        for (uint256 i = 0; i < loops; i++) {
            GasActionsFacet(address(operationalVault)).callFundGas(
                address(tBIC),
                beneficiary,
                fundingAmount
            );
        }

        assertEq(fundingAmount * loops, tBIC.balanceOf(address(beneficiary)), "balance mismatch");
        assertEq(depositTokenAmount - fundingAmount * loops, tBIC.balanceOf(address(operationalVault)), "balance mismatch");

        (
            uint256 periodSpendingToken,
            uint256 maxSpendingToken,
            uint256 currentUsageToken,
            uint256 lastSpendToken
        ) = GasActionsFacet(address(operationalVault)).getSpendingLimit(beneficiary, address(tBIC));

        assertEq(currentUsageToken, fundingAmount * loops);
        assertLt(block.timestamp, lastSpendToken + periodSpendingToken);

        vm.expectRevert();
        GasActionsFacet(address(operationalVault)).callFundGas(
            address(tBIC),
            beneficiary,
            fundingAmount
        );
        
        // fund ETH
        assertEq(0, beneficiary.balance, "balance ETH mismatch");

        for (uint256 i = 0; i < loops; i++) {
            GasActionsFacet(address(operationalVault)).callFundGas(
                address(0),
                beneficiary,
                fundingAmount
            );
        }
        
        assertEq(fundingAmount * loops, beneficiary.balance, "balance ETH mismatch");
        assertEq(depositETHAmount - fundingAmount * loops, address(operationalVault).balance, "balance ETH mismatch");

        (
            uint256 periodSpendingETH,
            uint256 maxSpendingETH,
            uint256 currentUsageETH,
            uint256 lastSpendETH
        ) = GasActionsFacet(address(operationalVault)).getSpendingLimit(beneficiary, address(0));

        assertEq(currentUsageETH, fundingAmount * loops);
        assertLt(block.timestamp, lastSpendETH + periodSpendingETH);

        vm.expectRevert();
        GasActionsFacet(address(operationalVault)).callFundGas(
            address(0),
            beneficiary,
            fundingAmount
        );

        vm.warp(block.timestamp + period + 1);

        GasActionsFacet(address(operationalVault)).callFundGas(
            address(tBIC),
            beneficiary,
            fundingAmount
        );
        GasActionsFacet(address(operationalVault)).callFundGas(
            address(0),
            beneficiary,
            fundingAmount
        );
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
        uint256 fundingAmount = 1e19;
        
        // deposit ETH to paymaster
        assertEq(depositETHAmount, address(operationalVault).balance, "balance mismatch");
        
        GasActionsFacet(address(operationalVault)).callDepositToPaymaster(
            address(entrypoint),
            address(tBIC),
            fundingAmount
        );
        
        assertEq(fundingAmount, entrypoint.balanceOf(address(tBIC)), "deposit balance mismatch");
        assertEq(depositETHAmount - fundingAmount, address(operationalVault).balance, "balance mismatch");

        (
            uint256 periodSpendingETH,
            uint256 maxSpendingETH,
            uint256 currentUsageETH,
            uint256 lastSpendETH
        ) = GasActionsFacet(address(operationalVault)).getSpendingLimit(address(tBIC), address(0));

        assertEq(currentUsageETH, fundingAmount);
        assertLt(block.timestamp, lastSpendETH + periodSpendingETH);
    }

    function test_callDepositToPaymaster_within_spendingLimit() public {
        vm.startPrank(operator);
        uint256 fundingAmount = 1e19;
        uint256 loops = 10;
        
        // deposit ETH to paymaster
        assertEq(depositETHAmount, address(operationalVault).balance, "balance mismatch");
        
        for (uint256 i = 0; i < loops; i++) {
            GasActionsFacet(address(operationalVault)).callDepositToPaymaster(
                address(entrypoint),
                address(tBIC),
                fundingAmount
            );
        }
        
        assertEq(fundingAmount * loops, entrypoint.balanceOf(address(tBIC)), "deposit balance mismatch");
        assertEq(depositETHAmount - fundingAmount * loops, address(operationalVault).balance, "balance mismatch");

        (
            uint256 periodSpendingETH,
            uint256 maxSpendingETH,
            uint256 currentUsageETH,
            uint256 lastSpendETH
        ) = GasActionsFacet(address(operationalVault)).getSpendingLimit(address(tBIC), address(0));

        assertEq(currentUsageETH, fundingAmount * loops);
        assertLt(block.timestamp, lastSpendETH + periodSpendingETH);

        vm.expectRevert();
        GasActionsFacet(address(operationalVault)).callDepositToPaymaster(
            address(entrypoint),
            address(tBIC),
            fundingAmount
        );

        vm.warp(block.timestamp + period + 1);
        GasActionsFacet(address(operationalVault)).callDepositToPaymaster(
            address(entrypoint),
            address(tBIC),
            fundingAmount
        );
    }

    function test_failed_callDepositToPaymaster_for_not_beneficiary() public {
        vm.startPrank(operator);
        uint256 ETHAmount = 1e19;
        address newBeneficiary = address(190212);
        
        // deposit ETH to paymaster
        assertEq(0, entrypoint.balanceOf(address(newBeneficiary)), "deposit balance mismatch");
        assertEq(depositETHAmount, address(operationalVault).balance, "balance mismatch");
        vm.expectRevert();
        GasActionsFacet(address(operationalVault)).callDepositToPaymaster(
            address(entrypoint),
            newBeneficiary,
            ETHAmount
        );
        assertEq(depositETHAmount, address(operationalVault).balance, "balance mismatch");
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
        assertEq(0, entrypoint.balanceOf(address(tBIC)), "deposit balance mismatch");
        assertEq(depositETHAmount, address(operationalVault).balance, "balance mismatch");
        vm.expectRevert();
        GasActionsFacet(address(operationalVault)).callDepositToPaymaster(
            address(entrypoint),
            address(tBIC),
            fundingAmount
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
        assertEq(0, entrypoint.balanceOf(address(tBIC)), "deposit balance mismatch");
        assertEq(depositETHAmount, address(operationalVault).balance, "balance mismatch");
        vm.expectRevert();
        GasActionsFacet(address(operationalVault)).callDepositToPaymaster(
            address(entrypoint),
            address(tBIC),
            fundingAmount
        );
    }
}