// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { LibAccess } from "../libraries/LibAccess.sol";
import { LibBeneficiary } from "../libraries/LibBeneficiary.sol";
import { LibAsset } from "../libraries/LibAsset.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";

contract GasActionsFacet {
    /// Errors
    error NotGasBeneficiary(address beneficiary);

    /// Events
    event UpdateGasBeneficiary(
        address indexed caller,
        address beneficiary,
        bool status
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
        IEntryPoint(entrypoint).depositTo{value: amount}(paymaster);
        emit DepositToPaymaster(msg.sender, entrypoint, paymaster, amount);
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

        LibAsset.transferAsset(assetAddress, payable(to), amount);
        emit FundGas(msg.sender, assetAddress, to, amount);
    }
}
