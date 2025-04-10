// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import {BicTokenPaymaster} from "../../src/BicTokenPaymaster.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {UserOperation} from "@account-abstraction/contracts/interfaces/UserOperation.sol";

contract ProdBicTokenPaymasterTest is Test {
    BicTokenPaymaster public paymaster;
    EntryPoint public entrypoint;
    address public paymasterAddress = 0xB1C3960aeeAf4C255A877da04b06487BBa698386;
    function setUp() public {
               // Setup Arbitrum fork at block 324832004
        // vm.createSelectFork("https://arb1.arbitrum.io/rpc", 324832004); // change to archive rpc to test this latter maybe using tenderly
        vm.createSelectFork("https://arb1.arbitrum.io/rpc");
        // Create interface to the problem contract
        paymaster = BicTokenPaymaster(payable(paymasterAddress));
        entrypoint = EntryPoint(payable(address(paymaster.entryPoint())));
    }

    function test_createTxWithPaymaster() public {
        vm.prank(paymaster.owner());
        paymaster.setMinSwapBackAmount(200_000 ether);
        // vm.startPrank(0x4A96b7cC073751Ef18085c440D6d2d63a40b896D);
        // paymaster.transfer(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697, 1);
        // console.log(paymaster.accumulatedLF());
        // paymaster.transfer(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697, 1);
        // console.log(paymaster.accumulatedLF());
        // paymaster.transfer(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697, 1);
        // console.log(paymaster.accumulatedLF());
        // paymaster.transfer(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697, 1);
        // paymaster.transfer(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697, 1);
        // paymaster.transfer(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697, 1);
        // paymaster.transfer(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697, 1);
        // paymaster.transfer(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697, 1);
        // paymaster.transfer(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697, 1);
        // paymaster.transfer(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697, 1);
        // paymaster.transfer(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697, 1);
        // paymaster.transfer(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697, 1);
        // paymaster.transfer(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697, 1);
        // paymaster.transfer(0xeaBcd21B75349c59a4177E10ed17FBf2955fE697, 1);
        // vm.stopPrank();

        UserOperation memory op = UserOperation({
            sender: 0x90675445BD3297431E7424c17474985eE676Cc69,
            nonce: 32176105424476458388173589839872,
            initCode: hex"",
            callData: hex"34fcd5be000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000b1c3960aeeaf4c255a877da04b06487bba698386000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb00000000000000000000000011e479dc86dda6a435c504b8ff17bcdba2a8dfe3000000000000000000000000000000000000000000000000000009184e72a00000000000000000000000000000000000000000000000000000000000",
            callGasLimit: 310200,
            verificationGasLimit: 92957,
            preVerificationGas: 86268,
            maxFeePerGas: 15635000,
            maxPriorityFeePerGas: 635000,
            paymasterAndData: hex"b1c3960aeeaf4c255a877da04b06487bba69838601000067f77a65000067f7735c000000000000000000000000000626d5000000000000000000000000000000000000000000000d0dc588fc4eca3f61ff46526839bfe0ff7dcccff9ff6cafe5511126f4383cea7947fc204a66682810b6501ab49e6923ae4f351d0e518df30849a315bb220c173402c5252d8b6b78c5861c",
            signature: hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000041fffffffffffffffffffffffffffffff0000000000000000000000000000000007aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1c00000000000000000000000000000000000000000000000000000000000000"
        });
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = op;
        // entrypoint.handleOps(ops,payable(address(this)));
        entrypoint.simulateHandleOp(op, address(0), hex"");

    }


}