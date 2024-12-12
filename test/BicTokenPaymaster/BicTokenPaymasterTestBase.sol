// SPDX-License-Identifier: MIT
 pragma solidity ^0.8.23;

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
    function setUp() public virtual {
        console.log("owner: ", owner);
        vm.prank(dev);
        address proxy = Upgrades.deployUUPSProxy(
            "BicTokenPaymaster.sol",
            abi.encodeCall(
                BicTokenPaymaster.initialize,
                (0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, owner, signers)
            )
        );
        bic = BicTokenPaymaster(proxy);
        vm.prank(owner);
        bic.transfer(holder1, holder1_init_amount);
    }
}