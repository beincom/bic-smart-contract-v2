// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "../lib/BicTokenPaymasterStorageV7.sol";
import "@account-abstraction-v7/contracts/interfaces/PackedUserOperation.sol";

import {console} from "forge-std/console.sol";
import {BicTokenPaymaster} from "../../src/BicTokenPaymaster.sol";

contract BicTokenPaymasterV7 is
    BicTokenPaymaster
{
    using BicTokenPaymasterStorageV7 for BicTokenPaymasterStorageV7.Data;

    BicTokenPaymasterStorageV7.Data internal _storage;

    function setEntryPointV7(address _entryPoint) external {
        _storage.entryPointv7 = _entryPoint;
    }

    function _requireFromEntryPointV7() internal virtual {
        require(msg.sender == address(_storage.entryPointv7), "Sender not EntryPoint");
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
