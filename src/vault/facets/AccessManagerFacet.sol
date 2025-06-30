// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibAccess } from "../libraries/LibAccess.sol";

contract AccessManagerFacet {
    /// Errors

    error CannotAuthoriseSelf();

    /// Events ///

    event ExecutionAllowed(address indexed account, bytes4 indexed method);
    event ExecutionDenied(address indexed account, bytes4 indexed method);

    /// External Methods ///

    /// @notice Sets whether a specific address can call a method
    /// @param _selector The method selector to set access for
    /// @param _executor The address to set method access for
    /// @param _canExecute Whether or not the address can execute the specified method
    function setCanExecute(
        bytes4 _selector,
        address _executor,
        bool _canExecute
    ) external {
        if (_executor == address(this)) {
            revert CannotAuthoriseSelf();
        }
        LibDiamond.enforceIsContractOwner();

        bool hasAccess = LibAccess.accessStorage().execAccess[_selector][_executor];

        // Only processd if state is changing
        if (hasAccess != _canExecute) {
            if (_canExecute) {
                LibAccess.addAccess(_selector, _executor);
                emit ExecutionAllowed(_executor, _selector);
            } else {
                LibAccess.removeAccess(_selector, _executor);
                emit ExecutionDenied(_executor, _selector);
            }
        }
    }

    /// @notice Check if a method can be executed by a specific address
    /// @param _selector The method selector to check
    /// @param _executor The address to check
    function addressCanExecuteMethod(
        bytes4 _selector,
        address _executor
    ) external view returns (bool) {
        return LibAccess.accessStorage().execAccess[_selector][_executor];
    }
}
