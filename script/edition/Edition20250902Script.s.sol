// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BicEdition} from "../../src/edition/BicEdition.sol";

contract Edition20250902Script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory editionUri = vm.envString("EDITION_URI");
        address editionOwner = vm.envAddress("EDITION_OWNER");
        address editionTreasury = vm.envAddress("EDITION_TREASURY");
        vm.startBroadcast(deployerPrivateKey);

        BicEdition bicEdition = new BicEdition(
            editionUri,
            editionOwner,
            editionTreasury
        );
        console.log("BicEdition deployed at:", address(bicEdition));

        vm.stopBroadcast();
    }
}