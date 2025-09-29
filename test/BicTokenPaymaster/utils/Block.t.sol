// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {BicTokenPaymasterTestBase} from "../BicTokenPaymasterTestBase.sol";
import {BicMultiBlock} from "../../../src/utils/MultiBlock.sol";
import {BicTokenPaymaster} from "../../../src/BicTokenPaymaster.sol";

contract BlockTest is BicTokenPaymasterTestBase {
    address badAddress = vm.addr(0xbad);
    BicMultiBlock multiBlock;

    event Cal(bytes mul);

    function setUp() public override {
        super.setUp();
        multiBlock = new BicMultiBlock(owner, address(bic));
    }

    function test_block() public {
        assertEq(bic.isBlocked(badAddress), false, "badAddress should not be blocked");
        vm.prank(owner);
        bic.blockAddress(badAddress, true);
        vm.stopPrank();
        assertEq(bic.isBlocked(badAddress), true, "badAddress should be blocked");
    }

    function test_multi_block() public {
        uint256 blockLength = 5;
        address[] memory blockAddresses = new address[](blockLength);
        for (uint256 i = 0; i < blockLength; i++) {
            address addr = address(uint160(uint256(keccak256(abi.encode(i)))));
            blockAddresses[i] = addr;
        }

        vm.startPrank(owner);
        bic.transferOwnership(address(multiBlock));
        multiBlock.multiBlock(blockAddresses);

        for (uint256 i = 0; i < blockLength; i++) {
            assertEq(bic.isBlocked(blockAddresses[i]), true);
        }

        multiBlock.transferBicOwner(owner);
        assertEq(bic.owner(), owner);

        vm.expectRevert();
        multiBlock.multiBlock(blockAddresses);
        vm.stopPrank();
    }

    function test_multi_unblock() public {
        uint256 blockLength = 5;
        address[] memory blockAddresses = new address[](blockLength);
        for (uint256 i = 0; i < blockLength; i++) {
            address addr = address(uint160(uint256(keccak256(abi.encode(i)))));
            blockAddresses[i] = addr;
        }

        vm.startPrank(owner);
        bic.transferOwnership(address(multiBlock));
        multiBlock.multiBlock(blockAddresses);

        for (uint256 i = 0; i < blockLength; i++) {
            assertEq(bic.isBlocked(blockAddresses[i]), true);
        }

        multiBlock.multiUnblock(blockAddresses);

        for (uint256 i = 0; i < blockLength; i++) {
            assertEq(bic.isBlocked(blockAddresses[i]), false);
        }

        multiBlock.transferBicOwner(owner);
        assertEq(bic.owner(), owner);
        vm.stopPrank();
    }
}