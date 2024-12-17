// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../contracts/FixedFeeOracle.sol";
import "@account-abstraction-v7/contracts/core/EntryPoint.sol" as EntryPointv7;
import "@account-abstraction-v7/contracts/samples/SimpleAccount.sol";
import "@account-abstraction-v7/contracts/samples/SimpleAccountFactory.sol";
import "forge-std/Test.sol";
import {BicTokenPaymasterTestBase} from "../BicTokenPaymasterTestBase.sol";
import {BicTokenPaymasterV7} from "../../contracts/BicTokenPaymasterV7.sol";
import {PackedUserOperation} from "@account-abstraction-v7/contracts/interfaces/PackedUserOperation.sol";


contract TestUpgradePaymaster is BicTokenPaymasterTestBase {
    SimpleAccountFactory smart_account_factory;
    uint256 user1_pkey = 0x001;
    address user1 = vm.addr(user1_pkey);
    uint256 public user1_init_amount = 10000 * 1e18;
    address user1AccountAddress;

    address public random_executor = address(0xeee);
    EntryPointv7.EntryPoint entrypointv7;

    function setUp() public virtual override {
        super.setUp();
        entrypointv7 = new EntryPointv7.EntryPoint();
        smart_account_factory = new SimpleAccountFactory(entrypointv7);
        user1AccountAddress = smart_account_factory.getAddress(user1, 0);

        vm.prank(owner);
        bic.transfer(user1AccountAddress, user1_init_amount);
    }

    // test utils
    function _packPaymasterStaticFields(
        address paymaster,
        uint128 validationGasLimit,
        uint128 postOpGasLimit
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes20(paymaster), bytes16(validationGasLimit), bytes16(postOpGasLimit));
    }

    function _setupUserOpWithSenderAndPaymaster(
        bytes memory _initCode,
        bytes memory _callDataForEntrypoint,
        address _sender,
        address _paymaster,
        uint128 _paymasterVerificationGasLimit,
        uint128 _paymasterPostOpGasLimit
    ) internal returns (PackedUserOperation[] memory ops) {
        uint256 nonce = entrypoint.getNonce(_sender, 0);
        PackedUserOperation memory op;

        {
            uint128 verificationGasLimit = 500_000;
            uint128 callGasLimit = 500_000;
            bytes32 packedAccountGasLimits = (bytes32(uint256(verificationGasLimit)) << 128) |
                                bytes32(uint256(callGasLimit));
            bytes32 packedGasLimits = (bytes32(uint256(1e9)) << 128) | bytes32(uint256(1e9));

            // Get user op fields
            op = PackedUserOperation({
                sender: _sender,
                nonce: nonce,
                initCode: _initCode,
                callData: _callDataForEntrypoint,
                accountGasLimits: packedAccountGasLimits,
                preVerificationGas: 500_000,
                gasFees: packedGasLimits,
                paymasterAndData: _packPaymasterStaticFields(
                    _paymaster,
                    _paymasterVerificationGasLimit,
                    _paymasterPostOpGasLimit
                ),
                signature: bytes("")
            });
        }

        // Sign UserOp
        bytes32 opHash = entrypointv7.getUserOpHash(op);
        bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(opHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1_pkey, msgHash);
        bytes memory userOpSignature = abi.encodePacked(r, s, v);

        op.signature = userOpSignature;

        // Store UserOp
        ops = new PackedUserOperation[](1);
        ops[0] = op;
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
        BicTokenPaymasterV7 bicV7 = BicTokenPaymasterV7(address(bic));

        vm.prank(owner);
        bicV7.setEntryPointV7(address(entrypointv7));

        entrypointv7.depositTo{value: 1*1e18}(address(bicV7));

        bytes memory initCallData = abi.encodeWithSignature("createAccount(address,uint256)", user1, 0);
        bytes memory initCode = abi.encodePacked(abi.encodePacked(address(smart_account_factory)), initCallData);


        vm.prank(owner);
        bicV7.addFactory(address(smart_account_factory));

        assertEq(address(bicV7.entryPoint()), address(entrypoint));

        PackedUserOperation[] memory ops = _setupUserOpWithSenderAndPaymaster(
            initCode,
            abi.encodeWithSignature(
                "execute(address,uint256,bytes)",
                address(0),
                0,
                bytes("")
            ),
             user1AccountAddress,
            address(bicV7),
            3e5,
            3e5
        );
        vm.prank(random_executor);
        entrypointv7.handleOps(ops, payable(random_executor));

        assertEq(isContract(user1AccountAddress), true);
    }
}