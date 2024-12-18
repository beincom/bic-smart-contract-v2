// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "../storage/BicStorageV7.sol";
import "@account-abstraction-v7/contracts/interfaces/PackedUserOperation.sol";

import {console} from "forge-std/console.sol";
import {BicTokenPaymaster} from "../../src/BicTokenPaymaster.sol";

contract BicTokenPaymasterV7 is
    BicTokenPaymaster
{
    using BicStorageV7 for BicStorageV7.Data;

    BicStorageV7.Data internal _storageV7;

    function setEntryPointV7(address _entryPoint) external {
        _storageV7.entryPointv7 = _entryPoint;
    }

    function _requireFromEntryPointV7() internal virtual {
        require(msg.sender == address(_storageV7.entryPointv7), "Sender not EntryPoint");
    }

    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 validationData) {
        _requireFromEntryPointV7();
        console.log("validatePaymasterUserOp");
        return ("", 0);
    }

    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) external {
        _requireFromEntryPointV7();
        console.log("postOp");
    }
}
