// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import "../../src/edition/BicEdition.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IClaimCondition} from "../../src/extension/interface/IClaimCondition.sol";

contract EditionBackendOperationClaimOnlyDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
        string memory editionUri = vm.envString("EDITION_URI");
        address editionOwner = vm.envAddress("EDITION_OWNER_TESTNET");
        address editionTreasury = vm.envAddress("EDITION_TREASURY_TESTNET");
        address currency = vm.envAddress("DROP_CURRENCY_TESTNET");
        address operator = vm.envAddress("OPERATOR_ADDRESS_TESTNET");

        address deployOwner = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        BicEdition bicEdition = new BicEdition(
//            "staging version - Beincom Birthday",
//            "staging-BD1111",
            "dev version - Hall Of Fame",
            "dev-HOF",
            editionUri,
            deployOwner,
            editionTreasury
        );

        console.log("BicEdition deployed at:", address(bicEdition));
        createDropConditions(bicEdition, currency, operator);

        vm.stopBroadcast();
    }
    function createDropConditions(
        BicEdition bicEdition,
        address currency,
        address operator
    ) internal {
        bytes32 userLeaf = keccak256(abi.encodePacked(operator, uint256(99999999), uint256(0), address(currency))); // 99999999 quantity limit, 0 price
        bytes32 merkleRoot = userLeaf; // For single leaf, root = leaf

        IClaimCondition.ClaimCondition[] memory conditionsForId0 = new IClaimCondition.ClaimCondition[](1);
        conditionsForId0[0] = IClaimCondition.ClaimCondition({
            startTimestamp: block.timestamp,
            maxClaimableSupply: 99999999,
            supplyClaimed: 0,
            quantityLimitPerWallet: 0,
            merkleRoot: merkleRoot,
            pricePerToken: 0,
            currency: currency,
            metadata: ""
        });
        bicEdition.setClaimConditions(
            0,
            conditionsForId0,
            false
        );
    }
}