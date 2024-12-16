// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../contracts/FixedFeeOracle.sol";
import "@account-abstraction-v7/contracts/samples/SimpleAccount.sol";
import "@account-abstraction-v7/contracts/samples/SimpleAccountFactory.sol";
import {BicTokenPaymasterTestBase} from "../BicTokenPaymasterTestBase.sol";
import "@account-abstraction-v7/contracts/core/EntryPoint.sol" as EntryPointv7;
import {BicTokenPaymasterV7} from "../../contracts/BicTokenPaymasterV7.sol";


contract TestUpgradePaymaster is BicTokenPaymasterTestBase {
    SimpleAccountFactory smart_account_factory;
    uint256 user1_pkey = 0x001;
    address user1 = vm.addr(user1_pkey);
    uint256 public user1_init_amount = 10000 * 1e18;
    address user1AccountAddress;

    address public random_executor = address(0xeee);
    EntryPointv7.EntryPoint entrypointv7;

//    error FailedOp(uint256 opIndex, string reason);

    function setUp() public virtual override {
        super.setUp();
        entrypointv7 = new EntryPointv7.EntryPoint();
        smart_account_factory = new SimpleAccountFactory(entrypointv7);
        bic.deposit{value: 1*1e18}();
        user1AccountAddress = smart_account_factory.getAddress(user1, 0);

        vm.prank(owner);
        bic.transfer(user1AccountAddress, user1_init_amount);
    }

    function isContract(address _addr) public view returns (bool){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function test_upgrade_paymasterv7() public {
        console.log("Testing upgrade to PaymasterV7");

        address newImplementation = address(new BicTokenPaymasterV7());
        vm.prank(owner);
        bic.upgradeToAndCall(newImplementation, "");

        vm.prank(owner);
        bic.setEntryPoint(address(entrypointv7));
        assertEq(address(bic.entryPoint()), address(entrypointv7));

//        bytes memory initCallData = abi.encodeWithSignature("createAccount(address,uint256)", user1, 0);
//        bytes memory initCode = abi.encodePacked(abi.encodePacked(address(smart_account_factory)), initCallData);
//
//        FixedFeeOracle oracle = new FixedFeeOracle();
//
//        vm.prank(owner);
//        bic.setOracle(address(oracle));
//
//        vm.prank(owner);
//        bic.addFactory(address(smart_account_factory));
//        UserOperation[] memory userOps = _setupUserOpExecute(
//            user1_pkey,
//            initCode,
//            address(0),
//            0,
//            bytes(""),
//            user1AccountAddress,
//            abi.encodePacked(
//                address(bic),
//                bic.ORACLE_MODE()
//            )
//        );
//        vm.prank(random_executor);
//        entrypointv7.handleOps(userOps, payable(random_executor));
//        assertEq(isContract(user1AccountAddress), true);
    }
}