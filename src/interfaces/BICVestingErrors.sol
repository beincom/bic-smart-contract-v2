// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

interface BICVestingErrors {
    error InvalidRedeemAllocation(
        address[] beneficiaries,
        uint16[] allocations
    );
    error InvalidBeneficiary(address beneficiary);
    error InvalidAllocations(uint16[] allocations);
    error InvalidVestingConfig(
        uint256 totalAmount,
        uint64 duration,
        uint64 redeemRate,
        address erc20
    );
    error NoRelease();
    error ExceedAllocation(uint256 maxAllocation, uint256 currentAllocation);
    error DuplicateBeneficiary(address beneficiary);
}
