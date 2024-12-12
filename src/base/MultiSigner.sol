// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* solhint-disable reason-string */

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * Helper class for creating a contract with multiple valid signers.
 */
abstract contract MultiSigner is OwnableUpgradeable {


    /// @notice Emitted when a signer is added.
    event SignerAdded(address signer);

    /// @notice Emitted when a signer is removed.
    event SignerRemoved(address signer);

    /// @notice Mapping of valid signers.
    mapping(address account => bool isValidSigner) public signers;

    function __MultiSigner_init(address[] memory _initialSigners) internal onlyInitializing {
        for (uint256 i = 0; i < _initialSigners.length; i++) {
            signers[_initialSigners[i]] = true;
        }
    }

    function removeSigner(address _signer) public onlyOwner {
        signers[_signer] = false;
        emit SignerRemoved(_signer);
    }

    function addSigner(address _signer) public onlyOwner {
        signers[_signer] = true;
        emit SignerAdded(_signer);
    }
}