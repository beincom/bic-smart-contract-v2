// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {BicTokenPaymaster} from "../BicTokenPaymaster.sol";

contract BicTokenPaymaster_2 is BicTokenPaymaster {
    uint256 fee;

    function setFee(uint256 _fee) public {
        fee = _fee;
    }

    function getFee() public view returns (uint256) {
        return fee;
    }
}
