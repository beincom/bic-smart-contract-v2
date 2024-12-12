// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BicTokenPaymasterTestBase} from "../BicTokenPaymasterTestBase.sol";

contract PaymasterTestBase is BicTokenPaymasterTestBase {

    function setUp() public virtual override {
        super.setUp();
    }
}