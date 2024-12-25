// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

interface PaymasterErrors {
    error PaymasterDataLength(uint256 paymasterDataLength, uint256 paymasterDataOffset);
    error PaymasterInvalidFactory(address factory);
    error PaymasterInvalidOracle(address oracle);
    error PaymasterLowGasPostOp(uint256 verificationGasLimit);
    error PaymasterInsufficient(address user, uint256 prefund);
    error PaymasterVerifyingModeDataLength(uint256 length);
    error PaymasterExchangeRate(uint256 exchangeRate);
    error PaymasterUnauthorizedVerifying();
    error PaymasterInvalidVerifyingMode(uint8 mode);
}