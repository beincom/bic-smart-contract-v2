// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

error NullAddress();
error NativeAssetTransferFailed();
error InvalidAmount();
error NoTransferToNullAddress();
error NullAddrIsNotAValidSpender();
error NullAddrIsNotAnERC20Token();
error InsufficientBalance(uint256 required, uint256 balance);
error ExceedSpendingLimit(uint256 spendingLimit);