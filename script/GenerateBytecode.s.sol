// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "../src/B139TokenPaymaster.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract GenerateBytecode is Script {
    function run() external {
        address entrypoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        address superController = 0xb99f671B24B8E1dA7a67EfbdB0B627BEF9068c65;
        address[] memory signers;
        bytes memory bytecode = abi.encodePacked(
            type(B139TokenPaymaster).creationCode,
            abi.encode(
                entrypoint,
                superController,
                signers
            )
        );

        console.logBytes(bytecode);
    }
}