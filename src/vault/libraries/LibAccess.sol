// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

library LibAccess {
    /// Errors
    error CannotAuthoriseSelf();
    error UnAuthorized();

    /// Types ///
    bytes32 internal constant ACCESS_STORAGE_POSITION =
        keccak256("operational.vault.access.storage");

    /// Storage ///
    struct AccessStorage {
        mapping(bytes4 => mapping(address => bool)) execAccess;
    }

    /// Events ///
    event AccessGranted(address indexed account, bytes4 indexed method);
    event AccessRevoked(address indexed account, bytes4 indexed method);

    /// @dev Fetch local storage
    function accessStorage()
        internal
        pure
        returns (AccessStorage storage accStor)
    {
        bytes32 position = ACCESS_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            accStor.slot := position
        }
    }

    /// @notice Gives an address permission to execute a method
    /// @param selector The method selector to execute
    /// @param executor The address to grant permission to
    function addAccess(bytes4 selector, address executor) internal {
        if (executor == address(this)) {
            revert CannotAuthoriseSelf();
        }
        AccessStorage storage accStor = accessStorage();
        accStor.execAccess[selector][executor] = true;
        emit AccessGranted(executor, selector);
    }

    /// @notice Revokes permission to execute a method
    /// @param selector The method selector to execute
    /// @param executor The address to revoke permission from
    function removeAccess(bytes4 selector, address executor) internal {
        AccessStorage storage accStor = accessStorage();
        accStor.execAccess[selector][executor] = false;
        emit AccessRevoked(executor, selector);
    }

    /// @notice Enforces access control by reverting if `msg.sender`
    ///     has not been given permission to execute `msg.sig`
    function enforceAccessControl() internal view {
        AccessStorage storage accStor = accessStorage();
        if (accStor.execAccess[msg.sig][msg.sender] != true)
            revert UnAuthorized();
    }
}
