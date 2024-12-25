// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../contracts/FixedFeeOracle.sol";
import "@account-abstraction/contracts/samples/SimpleAccount.sol";
import "@account-abstraction/contracts/samples/SimpleAccountFactory.sol";
import {BicTokenPaymasterTestBase} from "../BicTokenPaymasterTestBase.sol";
import "forge-std/Test.sol";

contract TestPaymaster is BicTokenPaymasterTestBase {
    SimpleAccountFactory smart_account_factory;
    uint256 user1_pkey = 0x001;
    address user1 = vm.addr(user1_pkey);
    uint256 public user1_init_amount = 10000 * 1e18;
    address user1AccountAddress;

    address public random_executor = address(0xeee);

//    error FailedOp(uint256 opIndex, string reason);

    function setUp() public virtual override {
        super.setUp();
        smart_account_factory = new SimpleAccountFactory(entrypoint);
        entrypoint.depositTo{value: 1*1e18}(address(bic));
        user1AccountAddress = smart_account_factory.getAddress(user1, 0);

        vm.prank(owner);
        bic.transfer(user1AccountAddress, user1_init_amount);
    }

    function _setupUserOp(
        uint256 _signerPKey,
        bytes memory _initCode,
        bytes memory _callDataForEntrypoint,
        address sender,
        bytes memory _paymasterAndData
    ) internal returns (UserOperation[] memory ops) {
        uint256 nonce = entrypoint.getNonce(sender, 0);

        // Get user op fields
        UserOperation memory op = UserOperation({
            sender: sender,
            nonce: nonce,
            initCode: _initCode,
            callData: _callDataForEntrypoint,
            callGasLimit: 500_000,
            verificationGasLimit: 500_000,
            preVerificationGas: 500_000,
            maxFeePerGas: 500_000,
            maxPriorityFeePerGas: 500_000,
            paymasterAndData: _paymasterAndData,
            signature: bytes("")
        });

        // Sign UserOp
        bytes32 opHash = entrypoint.getUserOpHash(op);
        bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(opHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPKey, msgHash);
        bytes memory userOpSignature = abi.encodePacked(r, s, v);

        op.signature = userOpSignature;

        // Store UserOp
        ops = new UserOperation[](1);
        ops[0] = op;
    }

    function _setupUserOpExecute(
        uint256 _signerPKey,
        bytes memory _initCode,
        address _target,
        uint256 _value,
        bytes memory _callData,
        address sender,
        bytes memory _paymasterAndData
    ) internal returns (UserOperation[] memory) {
        bytes memory callDataForEntrypoint = abi.encodeWithSignature(
            "execute(address,uint256,bytes)",
            _target,
            _value,
            _callData
        );

        return _setupUserOp(_signerPKey, _initCode, callDataForEntrypoint, sender, _paymasterAndData);
    }

    function _setupUserOpExecuteBatch(
        uint256 _signerPKey,
        bytes memory _initCode,
        address[] memory _target,
        uint256[] memory _value,
        bytes[] memory _callData,
        address sender,
        bytes memory _paymasterAndData
    ) internal returns (UserOperation[] memory) {
        bytes memory callDataForEntrypoint = abi.encodeWithSignature(
            "executeBatch(address[],uint256[],bytes[])",
            _target,
            _value,
            _callData
        );

        return _setupUserOp(_signerPKey, _initCode, callDataForEntrypoint, sender, _paymasterAndData);
    }

    function isContract(address _addr) private view returns (bool){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function test_createVerifyingUserOp() public {
        bytes memory initCallData = abi.encodeWithSignature("createAccount(address,uint256)", user1, 0);
        bytes memory initCode = abi.encodePacked(abi.encodePacked(address(smart_account_factory)), initCallData);

        bytes memory paymasterAndDataWithSig;
        {
            uint128 post_op_gas = 100_000;
            uint256 exchange_rate = 58000*1e18;
            uint48 validUntil = uint48(block.timestamp) + 60*30;
            uint48 validAfter = uint48(block.timestamp) - 1;
            bytes memory paymasterAndDataBeforeSig = abi.encodePacked(
                address(bic),
                bic.VERIFYING_MODE(),
                validUntil,
                validAfter,
                post_op_gas,
                exchange_rate
            );
            UserOperation[] memory userOps = _setupUserOpExecute(
                user1_pkey,
                initCode,
                address(0),
                0,
                bytes(""),
                user1AccountAddress,
                paymasterAndDataBeforeSig
            );
            UserOperation memory userOp = userOps[0];
            bytes32 verifyHash = bic.getHash(bic.VERIFYING_MODE(), userOp);
            bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(verifyHash);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(dev_private_key, msgHash);

            paymasterAndDataWithSig = abi.encodePacked(
                address(bic),
                bic.VERIFYING_MODE(),
                validUntil,
                validAfter,
                post_op_gas,
                exchange_rate,
                r, s, v
            );
        }

        UserOperation[] memory finalOps = _setupUserOpExecute(
            user1_pkey,
            initCode,
            address(0),
            0,
            bytes(""),
            user1AccountAddress,
            paymasterAndDataWithSig
        );
        vm.prank(random_executor);
        entrypoint.handleOps(finalOps, payable(random_executor));

        assertEq(isContract(user1AccountAddress), true);
    }

    function test_createOracleUserOp_failIfNoOracle() public {
        bytes memory initCallData = abi.encodeWithSignature("createAccount(address,uint256)", user1, 0);
        bytes memory initCode = abi.encodePacked(abi.encodePacked(address(smart_account_factory)), initCallData);

        UserOperation[] memory userOps = _setupUserOpExecute(
            user1_pkey,
            initCode,
            address(0),
            0,
            bytes(""),
            user1AccountAddress,
            abi.encodePacked(
                address(bic),
                bic.ORACLE_MODE()
            )
        );
        vm.prank(random_executor);
        vm.expectRevert();
        entrypoint.handleOps(userOps, payable(random_executor));
        assertEq(isContract(user1AccountAddress), false);
    }
    function test_createOracleUserOp_SuccessWithFixedFeeOracleAndFactory() public {
        bytes memory initCallData = abi.encodeWithSignature("createAccount(address,uint256)", user1, 0);
        bytes memory initCode = abi.encodePacked(abi.encodePacked(address(smart_account_factory)), initCallData);

        FixedFeeOracle oracle = new FixedFeeOracle();
        vm.prank(owner);
        bic.setOracle(address(oracle));
        vm.prank(owner);
        bic.addFactory(address(smart_account_factory));
        UserOperation[] memory userOps = _setupUserOpExecute(
            user1_pkey,
            initCode,
            address(0),
            0,
            bytes(""),
            user1AccountAddress,
            abi.encodePacked(
                address(bic),
                bic.ORACLE_MODE()
            )
        );
        vm.prank(random_executor);
        entrypoint.handleOps(userOps, payable(random_executor));
        assertEq(isContract(user1AccountAddress), true);
    }
}