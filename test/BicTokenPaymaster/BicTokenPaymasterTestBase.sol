// SPDX-License-Identifier: MIT
 pragma solidity ^0.8.23;

import "../../EntryPointv0.6/src/core/EntryPoint.sol";
import "../../src/BicTokenPaymaster.sol";
import "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract BicTokenPaymasterTestBase is Test {
    BicTokenPaymaster public bic;
    uint256 owner_private_key = 0xb1c;
    address owner = vm.addr(owner_private_key);
    uint256 dev_private_key = 0x238;
    address dev = vm.addr(dev_private_key);
    uint256 public holder1_pkey = 0x1;
    address public holder1 = vm.addr(holder1_pkey);
    uint256 public holder1_init_amount = 10000 * 1e18;
    address[] signers = [owner, dev];

    EntryPoint entryPoint;
    function setUp() public virtual {
        entryPoint = new EntryPoint();

        console.log("owner: ", owner);
        vm.prank(dev);
        address proxy = Upgrades.deployUUPSProxy(
            "BicTokenPaymaster.sol",
            abi.encodeCall(
                BicTokenPaymaster.initialize,
                (address(entryPoint), owner, signers)
            )
        );
        bic = BicTokenPaymaster(proxy);
        vm.prank(owner);
        bic.transfer(holder1, holder1_init_amount);
    }
}