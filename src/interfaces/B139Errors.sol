// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

interface B139Errors {
    error B139Unauthorized(address caller, address authorized);
    error B139InvalidLFStartTime(uint256 newLFStartTime);
    error B139InvalidMinMaxLF(uint256 min, uint256 max);
    error B139LFReduction(uint256 LFReduction);
    error B139LFPeriod(uint256 LFPeriod);
    error B139LFStartTime(uint256 LFStartTime);
    error B139InvalidTimestampPrePublicRound(uint256 startTime, uint256 endTime);
    error B139InvalidCoolDown(uint256 coolDown);
    error B139InvalidMaxAmountPerBuy(uint256 maxAmountPerBuy);
    error B139PrePublicWhitelist(address[] addresses, uint256[] categories);
    error B139ValidateBeforeTransfer(address from, address to);
    error B139InvalidCategory(address user, uint256 category);
    error B139NotActiveRound(address user, uint256 category);
    error B139WaitForCoolDown(address user, uint256 coolDown);
    error B139MaxAmountPerBuy(address user, uint256 maxAmountPerBuy);
}