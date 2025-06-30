// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { LibAccess } from "../libraries/LibAccess.sol";
import { LibBeneficiary } from "../libraries/LibBeneficiary.sol";
import { LibAsset } from "../libraries/LibAsset.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";
import { ExceedSpendingLimit } from "../utils/GenericErrors.sol";

contract GasActionsFacet {
    /// Errors
    error NotGasBeneficiary(address beneficiary);

    /// Events
    event UpdateGasBeneficiary(
        address caller,
        address indexed beneficiary,
        bool status
    );
    event UpdateGasBeneficiarySpendingLimit(
        address caller,
        address indexed beneficiary,
        address assetAddress,
        uint256 spendingLimit,
        uint256 period
    );
    event DepositToPaymaster(
        address indexed caller,
        address entrypoint,
        address paymaster,
        uint256 amount
    );
    event FundGas(
        address indexed caller,
        address assetAddress,
        address indexed to,
        uint256 amount
    );

    /**
     * @notice Check spending limit of a beneficiary.
     * @param beneficiary beneficiary address.
     * @param assetAddress asset address
     */
    function getSpendingLimit(
        address beneficiary,
        address assetAddress
    ) external view returns (
        uint256 period,
        uint256 maxSpendingPerPeriod,
        uint256 currentUsage,
        uint256 lastSpendingTimestamp
    ) {
        (
            period,
            maxSpendingPerPeriod,
            currentUsage,
            lastSpendingTimestamp
        ) = LibBeneficiary.getSpendingLimit(beneficiary, assetAddress);
    }

    /**
     * @notice Set gas beneficiary.
     * @param beneficiary beneficiary address.
     * @param status beneficiary status
     */
    function setGasBeneficiary(
        address beneficiary,
        bool status
    ) external {
        LibDiamond.enforceIsContractOwner();
        if (status) {
            LibBeneficiary.addBeneficiary(beneficiary);
        } else {
            LibBeneficiary.removeBeneficiary(beneficiary);
        }
        emit UpdateGasBeneficiary(msg.sender, beneficiary, status);
    }

    /**
     * @notice Set spending limit of a beneficiary.
     * @param beneficiary beneficiary address.
     * @param assetAddress asset address
     * @param spendingLimit spending limit amount
     * @param period period of spending limit
     */
    function setBeneficiarySpendingLimit(
        address beneficiary,
        address assetAddress,
        uint256 spendingLimit,
        uint256 period
    ) external {
        LibDiamond.enforceIsContractOwner();
        LibBeneficiary.updateSpendingLimit(beneficiary, assetAddress, spendingLimit, period);
        emit UpdateGasBeneficiarySpendingLimit(msg.sender, beneficiary, assetAddress, spendingLimit, period);
    }
    
    /**
     * @notice Deposit to Paymaster.
     * @param entrypoint entrypoint address.
     * @param paymaster beneficiary status
     * @param amount deposit amount
     */
    function callDepositToPaymaster(
        address entrypoint,
        address paymaster,
        uint256 amount
    ) external {
        LibAccess.enforceAccessControl();

        if (!LibBeneficiary.isBeneficiary(paymaster)) {
            revert NotGasBeneficiary(paymaster);
        }

        uint256 spendingAmount = LibBeneficiary.updateSpending(paymaster, address(0), amount);

        IEntryPoint(entrypoint).depositTo{value: spendingAmount}(paymaster);
        emit DepositToPaymaster(msg.sender, entrypoint, paymaster, spendingAmount);
    }

    /**
     * @notice Fund gas.
     * @param assetAddress asset address.
     * @param to beneficiary
     * @param amount funding amount
     */
    function callFundGas(
        address assetAddress,
        address to,
        uint256 amount
    ) external {
        LibAccess.enforceAccessControl();

        if (!LibBeneficiary.isBeneficiary(to)) {
            revert NotGasBeneficiary(to);
        }

        uint256 spendingAmount = LibBeneficiary.updateSpending(to, assetAddress, amount);

        LibAsset.transferAsset(assetAddress, payable(to), spendingAmount);
        emit FundGas(msg.sender, assetAddress, to, spendingAmount);
    }
}
