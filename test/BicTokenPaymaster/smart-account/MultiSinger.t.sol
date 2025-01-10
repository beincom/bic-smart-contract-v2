// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BicTokenPaymasterTestBase.sol";

contract TestMultiSinger is BicTokenPaymasterTestBase {
    address public random_signer = vm.addr(0x575);
    function setUp() public virtual override {
        super.setUp();
    }

    function test_addAndRemoveSigner() public {
        assertEq(bic.signers(owner), true);
        assertEq(bic.signers(dev), true);
        assertEq(bic.signers(random_signer), false);
        vm.startPrank(owner);
        bic.addSigner(random_signer);
        assertEq(bic.signers(random_signer), true);
        bic.removeSigner(random_signer);
        assertEq(bic.signers(random_signer), false);
        vm.stopPrank();
    }
}