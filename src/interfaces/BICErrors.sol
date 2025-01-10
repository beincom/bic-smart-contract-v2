// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

interface BICErrors {
    error BICUnauthorized(address caller, address authorized);
    error BICInvalidLFStartTime(uint256 newLFStartTime);
    error BICInvalidMinMaxLF(uint256 min, uint256 max);
    error BICLFReduction(uint256 LFReduction);
    error BICLFPeriod(uint256 LFPeriod);
    error BICLFStartTime(uint256 LFStartTime);
    error BICPrePublicWhitelist(address[] addresses, uint256[] categories);
    error BICValidateBeforeTransfer(address from);
    error BICInvalidCategory(address user, uint256 category);
    error BICNotActiveRound(address user, uint256 category);
    error BICWaitForCoolDown(address user, uint256 coolDown);
    error BICMaxAmountPerBuy(address user, uint256 maxAmountPerBuy);
}