// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BicTokenPaymasterTestBase.sol";
import {BICErrors} from "../../../src/interfaces/BICErrors.sol";

contract Privileges is BicTokenPaymasterTestBase {
    address public randomUser1 = vm.addr(0xabcde);
    address public randomUser2 = vm.addr(0xabcdd);

    function test_block_address_send_and_receive() public {
        vm.prank(owner);
        bic.transfer(randomUser1, 1000);
        vm.startPrank(randomUser1);
        bic.transfer(randomUser2, 500);
        vm.startPrank(owner);
        bic.blockAddress(randomUser1, true);
        vm.startPrank(randomUser1);
        vm.expectRevert(abi.encodeWithSelector(
            BICErrors.BICValidateBeforeTransfer.selector,
            randomUser1, randomUser2
        ));
        bic.transfer(randomUser2, 100);
        vm.stopPrank();
        vm.prank(randomUser2);
        vm.expectRevert(abi.encodeWithSelector(
            BICErrors.BICValidateBeforeTransfer.selector,
            randomUser2, randomUser1
        ));
        bic.transfer(randomUser1, 100);
    }

    function test_remove_exclusive_privilege_as_blocking_address() public {
        address[] memory excluded = new address[](2);
        excluded[0] = randomUser1;
        excluded[1] = randomUser2;
        vm.prank(owner);
        bic.bulkExcluded(excluded, true);
        assertEq(true, bic.isExcluded(randomUser1));
        assertEq(true, bic.isExcluded(randomUser2));
        vm.startPrank(owner);
        bic.blockAddress(randomUser1, true);
        assertEq(false, bic.isExcluded(randomUser1));
    }
}