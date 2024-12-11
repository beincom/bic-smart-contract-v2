// SPDX-License-Identifier: MIT
 pragma solidity ^0.8.23;

import "../../src/BicTokenPaymaster.sol";
import "forge-std/Test.sol";

contract BicTokenPaymasterTestBase is Test {
    BicTokenPaymaster public bic;
    uint256 owner_private_key = 0xb1c;
    address owner = vm.addr(owner_private_key);
    uint256 public holder1_pkey = 0x1;
    address public holder1 = vm.addr(holder1_pkey);
    uint256 public holder1_init_amount = 10000 * 1e18;

    function setUp() public virtual {
        bic = new BicTokenPaymaster(IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789), owner);
        vm.prank(owner);
        bic.transfer(holder1, holder1_init_amount);
    }
}