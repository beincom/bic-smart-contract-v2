// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@account-abstraction/contracts/samples/IOracle.sol";

contract FixedFeeOracle is IOracle {
    uint256 public rateBicUsd = 6800000;
    uint8 public constant decimals = 8;
    uint256 public constant rateEthUsd = 4000*1e8;

    function getTokenValueOfEth(uint256 ethOutput) external view override returns (uint256 tokenInput) {
        return ethOutput *  rateEthUsd / rateBicUsd;
    }
}