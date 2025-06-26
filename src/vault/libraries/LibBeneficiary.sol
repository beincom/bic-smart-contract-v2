// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { NullAddress } from "../utils/GenericErrors.sol";

library LibBeneficiary {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// Errors
    error BeneficiaryAlreadyAdded();
    error BeneficiaryNotExist();

    /// Storage
    struct BeneficiaryStorage {
        EnumerableSet.AddressSet beneficiaries;
    }

    /// Events
    event BeneficiaryAdded(
        address caller,
        address beneficiary
    );
    event BeneficiaryRemoved(
        address caller,
        address beneficiary
    );

    bytes32 internal constant BENEFICIARY_STORAGE_POSITION =
        keccak256("operational.vault.beneficiary.storage");

    /// Events ///
    event AccessGranted(address indexed account, bytes4 indexed method);
    event AccessRevoked(address indexed account, bytes4 indexed method);

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
}
