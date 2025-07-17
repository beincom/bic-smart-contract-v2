// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {DropErc1155} from "../../src/drop-edition/DropErc1155.sol";

contract DropErc1155DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Configuration parameters
        string memory baseURI = vm.envOr("DROP_BASE_URI", string("https://raw.githubusercontent.com/viettu-bic/20250902-collection-metadata/refs/heads/main/profile.json"));
        address owner = vm.envOr("DROP_OWNER", address(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697));
        address primarySaleRecipient = vm.envOr("DROP_PRIMARY_SALE_RECIPIENT", address(0xC9167C15f539891B625671b030a0Db7b8c08173f));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy DropErc1155 contract
        DropErc1155 dropErc1155 = new DropErc1155(
            baseURI,
            owner,
            primarySaleRecipient
        );
        
        console.log("DropErc1155 deployed at:", address(dropErc1155));
        console.log("Base URI:", baseURI);
        console.log("Owner:", owner);
        console.log("Primary Sale Recipient:", primarySaleRecipient);
        
        vm.stopBroadcast();
    }
}
