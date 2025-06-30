// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { NullAddress, ExceedSpendingLimit } from "../utils/GenericErrors.sol";

library LibBeneficiary {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// Errors
    error BeneficiaryAlreadyAdded();
    error BeneficiaryNotExist();

    /// Storage
    struct SpendingLimit {
        uint256 period;
        uint256 maxSpendingPerPeriod;
        uint256 currentUsage;
        uint256 lastSpendingTimestamp;
    }

    struct BeneficiaryStorage {
        EnumerableSet.AddressSet beneficiaries;
        // beneficiary -> asset address -> spending limit
        mapping(address => mapping(address => SpendingLimit)) spendingLimits;
    }

    bytes32 internal constant BENEFICIARY_STORAGE_POSITION =
        keccak256("operational.vault.beneficiary.storage");

    /// Events
    event BeneficiaryAdded(address caller, address beneficiary);
    event BeneficiaryRemoved(address caller, address beneficiary);
    event SpendingLimitUpdated(
        address caller,
        address indexed account,
        address assetAddress,
        uint256 spendingLimit,
        uint256 period
    );

    /// @dev Fetch local storage
    function getStorage()
        internal
        pure
        returns (BeneficiaryStorage storage st)
    {
        bytes32 position = BENEFICIARY_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            st.slot := position
        }
    }

    /**
     * @notice Check is beneficiary.
     * @param beneficiary beneficiary address.
     */
    function isBeneficiary(
        address beneficiary
    ) internal view returns (bool) {
        BeneficiaryStorage storage s = getStorage();
        return s.beneficiaries.contains(beneficiary);
    }

    /**
     * @notice Check spending limit of a beneficiary.
     * @param beneficiary beneficiary address.
     * @param assetAddress asset address
     */
    function getSpendingLimit(
        address beneficiary,
        address assetAddress
    ) internal view returns (uint256, uint256, uint256, uint256) {
        BeneficiaryStorage storage s = getStorage();
        if (!s.beneficiaries.contains(beneficiary)) {
           revert BeneficiaryNotExist();
        }
        SpendingLimit storage spendingLimit = s.spendingLimits[beneficiary][assetAddress];
        
        return (
            spendingLimit.period,
            spendingLimit.maxSpendingPerPeriod,
            spendingLimit.currentUsage,
            spendingLimit.lastSpendingTimestamp
        );
    }

    /**
     * @notice Check spending amount.
     * @param beneficiary beneficiary address.
     * @param assetAddress asset address
     */
    function canSpend(
        address beneficiary,
        address assetAddress
    ) internal view returns (uint256) {
        BeneficiaryStorage storage s = getStorage();
        SpendingLimit storage spendingLimit = s.spendingLimits[beneficiary][assetAddress];
        if (spendingLimit.lastSpendingTimestamp == 0 ||
            spendingLimit.lastSpendingTimestamp + spendingLimit.period <= block.timestamp
        ) {
            return spendingLimit.maxSpendingPerPeriod;
        }

        if (spendingLimit.lastSpendingTimestamp + spendingLimit.period > block.timestamp &&
            spendingLimit.currentUsage != 0
        ) {
            return spendingLimit.maxSpendingPerPeriod - spendingLimit.currentUsage;
        }
        
        return 0;
    }

    /**
     * @notice Get all beneficiaries.
     */
    function getBeneficiaries() internal view returns (address[] memory) {
        BeneficiaryStorage storage s = getStorage();
        return s.beneficiaries.values();
    }

    /**
     * @notice Add beneficiary.
     * @param beneficiary beneficiary address.
     */
    function addBeneficiary(
        address beneficiary
    ) internal {
        if (beneficiary == address(0)) {
            revert NullAddress();
        }

        BeneficiaryStorage storage s = getStorage();
        if (s.beneficiaries.contains(beneficiary)) {
           revert BeneficiaryAlreadyAdded();
        }

        s.beneficiaries.add(beneficiary);
        emit BeneficiaryAdded(msg.sender, beneficiary);
    }

    /**
     * @notice Remove beneficiary.
     * @param beneficiary beneficiary address.
     */
    function removeBeneficiary(
        address beneficiary
    ) internal {
        if (beneficiary == address(0)) {
            revert NullAddress();
        }

        BeneficiaryStorage storage s = getStorage();
        if (!s.beneficiaries.contains(beneficiary)) {
           revert BeneficiaryNotExist();
        }

        s.beneficiaries.remove(beneficiary);
        emit BeneficiaryRemoved(msg.sender, beneficiary);
    }

    /**
     * @notice Update spending limit of a beneficiary.
     * @param beneficiary beneficiary address.
     * @param assetAddress asset addrsss
     * @param spendingLimit spending limit amount
     * @param period period of spending limit
     */
    function updateSpendingLimit(
        address beneficiary,
        address assetAddress,
        uint256 spendingLimit,
        uint256 period
    ) internal {
        if (beneficiary == address(0)) {
            revert NullAddress();
        }

        BeneficiaryStorage storage s = getStorage();
        if (!s.beneficiaries.contains(beneficiary)) {
           revert BeneficiaryNotExist();
        }

        s.spendingLimits[beneficiary][assetAddress].maxSpendingPerPeriod = spendingLimit;
        s.spendingLimits[beneficiary][assetAddress].period = period;
        emit SpendingLimitUpdated(msg.sender, beneficiary, assetAddress, spendingLimit, period);
    }

    /**
     * @notice Update spending limit of a beneficiary.
     * @param beneficiary beneficiary address.
     * @param assetAddress asset addrsss
     * @param spendingAmount spending amount
     */
    function updateSpending(
        address beneficiary,
        address assetAddress,
        uint256 spendingAmount
    ) internal returns (uint256) {
        if (beneficiary == address(0)) {
            revert NullAddress();
        }

        BeneficiaryStorage storage s = getStorage();
        if (!s.beneficiaries.contains(beneficiary)) {
           revert BeneficiaryNotExist();
        }

        SpendingLimit storage spendingLimit = s.spendingLimits[beneficiary][assetAddress];
        uint256 remainingSpending = canSpend(beneficiary, assetAddress);
        uint256 actualSpending = spendingAmount <= remainingSpending ? spendingAmount : remainingSpending;
        if (remainingSpending == 0) {
            revert ExceedSpendingLimit(spendingLimit.maxSpendingPerPeriod);
        }

        if (spendingAmount <= remainingSpending) {
            spendingLimit.currentUsage += spendingAmount;
            spendingLimit.lastSpendingTimestamp = block.timestamp;
        } else {
            spendingLimit.currentUsage = 0;
            spendingLimit.lastSpendingTimestamp = block.timestamp;
        }

        return actualSpending;
    }
}
