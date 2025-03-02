// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "../src/vest/BICVesting.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract GenerateBytecode is Script {
    function run() external {
        address entrypoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        address superController = 0x85980dcd69b253C480ea730e8FA33C3F33De5a78;
        address[] memory signers;
        bytes memory bytecode = abi.encodePacked(
            type(BICVesting).creationCode,
            abi.encode(
//                superController
            )
        );

        console.logBytes(bytecode);
    }
}
