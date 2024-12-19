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

    // error FailedOp(uint256 opIndex, string reason);

    function setUp() public virtual override {
        super.setUp();
        smart_account_factory = new SimpleAccountFactory(entrypoint);
        bic.deposit{value: 1 * 1e18}();
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
    ) internal view returns (UserOperation[] memory ops) {
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
    ) internal view returns (UserOperation[] memory) {
        bytes memory callDataForEntrypoint = abi.encodeWithSignature(
            "execute(address,uint256,bytes)",
            _target,
            _value,
            _callData
        );

        return
            _setupUserOp(
                _signerPKey,
                _initCode,
                callDataForEntrypoint,
                sender,
                _paymasterAndData
            );
    }

    function _setupUserOpExecuteBatch(
        uint256 _signerPKey,
        bytes memory _initCode,
        address[] memory _target,
        uint256[] memory _value,
        bytes[] memory _callData,
        address sender,
        bytes memory _paymasterAndData
    ) internal view returns (UserOperation[] memory) {
        bytes memory callDataForEntrypoint = abi.encodeWithSignature(
            "executeBatch(address[],uint256[],bytes[])",
            _target,
            _value,
            _callData
        );

        return
            _setupUserOp(
                _signerPKey,
                _initCode,
                callDataForEntrypoint,
                sender,
                _paymasterAndData
            );
    }

    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function test_createVerifyingUserOp() public {
        bytes memory initCallData = abi.encodeWithSignature(
            "createAccount(address,uint256)",
            user1,
            0
        );
        bytes memory initCode = abi.encodePacked(
            abi.encodePacked(address(smart_account_factory)),
            initCallData
        );

        bytes memory paymasterAndDataWithSig;
        {
            uint128 post_op_gas = 100_000;
            uint256 exchange_rate = 58000 * 1e18;
            uint48 validUntil = uint48(block.timestamp) + 60 * 30;
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
            bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
                verifyHash
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(dev_private_key, msgHash);

            paymasterAndDataWithSig = abi.encodePacked(
                address(bic),
                bic.VERIFYING_MODE(),
                validUntil,
                validAfter,
                post_op_gas,
                exchange_rate,
                r,
                s,
                v
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
        bytes memory initCallData = abi.encodeWithSignature(
            "createAccount(address,uint256)",
            user1,
            0
        );
        bytes memory initCode = abi.encodePacked(
            abi.encodePacked(address(smart_account_factory)),
            initCallData
        );

        UserOperation[] memory userOps = _setupUserOpExecute(
            user1_pkey,
            initCode,
            address(0),
            0,
            bytes(""),
            user1AccountAddress,
            abi.encodePacked(address(bic), bic.ORACLE_MODE())
        );
        vm.prank(random_executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOp.selector,
                0,
                "AA33 reverted: TokenSingletonPaymaster: no oracle"
            )
        );
        entrypoint.handleOps(userOps, payable(random_executor));
        assertEq(isContract(user1AccountAddress), false);
    }

    function test_createOracleUserOp_SuccessWithFixedFeeOracleAndFactory()
        public
    {
        bytes memory initCallData = abi.encodeWithSignature(
            "createAccount(address,uint256)",
            user1,
            0
        );
        bytes memory initCode = abi.encodePacked(
            abi.encodePacked(address(smart_account_factory)),
            initCallData
        );

        FixedFeeOracle oracle = new FixedFeeOracle();
        console.log("die here");
        vm.prank(owner);
        bic.setOracle(address(oracle));
        console.log("or here");
        vm.prank(owner);
        bic.addFactory(address(smart_account_factory));
        console.log("or not");
        UserOperation[] memory userOps = _setupUserOpExecute(
            user1_pkey,
            initCode,
            address(0),
            0,
            bytes(""),
            user1AccountAddress,
            abi.encodePacked(address(bic), bic.ORACLE_MODE())
        );
        vm.prank(random_executor);
        entrypoint.handleOps(userOps, payable(random_executor));
        assertEq(isContract(user1AccountAddress), true);
    }

    function test_createVerifyingUserOp_invalidSignature() public {
        bytes memory initCallData = abi.encodeWithSignature(
            "createAccount(address,uint256)",
            user1,
            0
        );
        bytes memory initCode = abi.encodePacked(
            abi.encodePacked(address(smart_account_factory)),
            initCallData
        );

        bytes memory paymasterAndDataWithInvalidSig;
        {
            uint128 post_op_gas = 100_000;
            uint256 exchange_rate = 58000 * 1e18;
            uint48 validUntil = uint48(block.timestamp) + 60 * 30;
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
            bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
                verifyHash
            );

            // Intentionally use a wrong private key for signing
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x999, msgHash); // Invalid private key

            // bytes memory invalidSignature = abi.encodePacked(r, s, v);
            paymasterAndDataWithInvalidSig = abi.encodePacked(
                address(bic),
                bic.VERIFYING_MODE(),
                validUntil,
                validAfter,
                post_op_gas,
                exchange_rate,
                r,
                s,
                v // Invalid signature appended
            );
        }

        UserOperation[] memory finalOps = _setupUserOpExecute(
            user1_pkey,
            initCode,
            address(0),
            0,
            bytes(""),
            user1AccountAddress,
            paymasterAndDataWithInvalidSig
        );

        vm.prank(random_executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOp.selector,
                0,
                "AA34 signature error"
            )
        );
        entrypoint.handleOps(finalOps, payable(random_executor));

        assertEq(isContract(user1AccountAddress), false);
    }

    function test_createVerifyingUserOp_expiredPaymasterData() public {
        bytes memory initCallData = abi.encodeWithSignature(
            "createAccount(address,uint256)",
            user1,
            0
        );
        bytes memory initCode = abi.encodePacked(
            abi.encodePacked(address(smart_account_factory)),
            initCallData
        );

        // Set block timestamp to a known value
        vm.warp(1000000);

        bytes memory paymasterAndDataWithExpired;
        {
            uint128 post_op_gas = 100_000;
            uint256 exchange_rate = 58000 * 1e18;
            uint48 validUntil = uint48(block.timestamp - 60); // expired 60 seconds ago
            uint48 validAfter = uint48(block.timestamp - 120); // valid from 120 seconds ago
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
            bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
                verifyHash
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(dev_private_key, msgHash);

            paymasterAndDataWithExpired = abi.encodePacked(
                address(bic),
                bic.VERIFYING_MODE(),
                validUntil,
                validAfter,
                post_op_gas,
                exchange_rate,
                r,
                s,
                v
            );
        }

        UserOperation[] memory finalOps = _setupUserOpExecute(
            user1_pkey,
            initCode,
            address(0),
            0,
            bytes(""),
            user1AccountAddress,
            paymasterAndDataWithExpired
        );

        vm.prank(random_executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOp.selector,
                0,
                "AA32 paymaster expired or not due"
            )
        );
        entrypoint.handleOps(finalOps, payable(random_executor));

        assertEq(isContract(user1AccountAddress), false);
    }

    function test_createVerifyingUserOp_insufficientGasDeposit() public {
        bytes memory initCallData = abi.encodeWithSignature(
            "createAccount(address,uint256)",
            user1,
            0
        );
        bytes memory initCode = abi.encodePacked(
            abi.encodePacked(address(smart_account_factory)),
            initCallData
        );

        // Get current deposit
        uint256 currentDeposit = entrypoint.balanceOf(address(bic));

        // Withdraw most of the deposit, leaving only a tiny amount (not enough for gas)
        vm.prank(owner);
        bic.withdrawTo(payable(address(0x999)), currentDeposit - 1000);

        bytes memory paymasterAndDataWithSig;
        {
            uint128 post_op_gas = 100_000;
            uint256 exchange_rate = 58000 * 1e18;
            uint48 validUntil = uint48(block.timestamp) + 60 * 30;
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
            bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
                verifyHash
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(dev_private_key, msgHash);

            paymasterAndDataWithSig = abi.encodePacked(
                address(bic),
                bic.VERIFYING_MODE(),
                validUntil,
                validAfter,
                post_op_gas,
                exchange_rate,
                r,
                s,
                v
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

        // Calculate required gas
        uint256 requiredGas = finalOps[0].callGasLimit +
            finalOps[0].verificationGasLimit +
            finalOps[0].preVerificationGas;
        uint256 maxFeePerGas = finalOps[0].maxFeePerGas;
        uint256 requiredDeposit = requiredGas * maxFeePerGas;

        // Log values for debugging
        console.log("Current deposit:", entrypoint.balanceOf(address(bic)));
        console.log("Required deposit:", requiredDeposit);

        vm.prank(random_executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOp.selector,
                0,
                "AA31 paymaster deposit too low"
            )
        );
        entrypoint.handleOps(finalOps, payable(random_executor));

        assertEq(isContract(user1AccountAddress), false);
    }

    function test_createVerifyingUserOp_incorrectGasLimits() public {
        bytes memory initCallData = abi.encodeWithSignature(
            "createAccount(address,uint256)",
            user1,
            0
        );
        bytes memory initCode = abi.encodePacked(
            abi.encodePacked(address(smart_account_factory)),
            initCallData
        );

        // Test with too low gas limits
        bytes memory paymasterAndDataWithSig;
        {
            uint128 post_op_gas = 100_000;
            uint256 exchange_rate = 58000 * 1e18;
            uint48 validUntil = uint48(block.timestamp) + 60 * 30;
            uint48 validAfter = uint48(block.timestamp) - 1;
            bytes memory paymasterAndDataBeforeSig = abi.encodePacked(
                address(bic),
                bic.VERIFYING_MODE(),
                validUntil,
                validAfter,
                post_op_gas,
                exchange_rate
            );

            UserOperation memory userOp = UserOperation({
                sender: user1AccountAddress,
                nonce: 0,
                initCode: initCode,
                callData: bytes(""),
                callGasLimit: 100_000,
                verificationGasLimit: 1_000, // Set extremely low verification gas
                preVerificationGas: 21000,
                maxFeePerGas: 100 gwei,
                maxPriorityFeePerGas: 100 gwei,
                paymasterAndData: paymasterAndDataBeforeSig,
                signature: bytes("")
            });

            bytes32 verifyHash = bic.getHash(bic.VERIFYING_MODE(), userOp);
            bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
                verifyHash
            );

            // Paymaster signature in its own scope
            {
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                    dev_private_key,
                    msgHash
                );
                paymasterAndDataWithSig = abi.encodePacked(
                    address(bic),
                    bic.VERIFYING_MODE(),
                    validUntil,
                    validAfter,
                    post_op_gas,
                    exchange_rate,
                    r,
                    s,
                    v
                );
            }
        }

        UserOperation memory finalOp = UserOperation({
            sender: user1AccountAddress,
            nonce: 0,
            initCode: initCode,
            callData: bytes(""),
            callGasLimit: 100_000,
            verificationGasLimit: 1_000, // Set extremely low verification gas
            preVerificationGas: 21000,
            maxFeePerGas: 100 gwei,
            maxPriorityFeePerGas: 100 gwei,
            paymasterAndData: paymasterAndDataWithSig,
            signature: bytes("")
        });

        // User signature in its own scope
        {
            bytes32 userOpHash = entrypoint.getUserOpHash(finalOp);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1_pkey, userOpHash);
            finalOp.signature = abi.encodePacked(r, s, v);
        }

        UserOperation[] memory finalOps = new UserOperation[](1);
        finalOps[0] = finalOp;

        // Log gas values for debugging
        console.log("callGasLimit:", finalOps[0].callGasLimit);
        console.log("verificationGasLimit:", finalOps[0].verificationGasLimit);
        console.log("preVerificationGas:", finalOps[0].preVerificationGas);

        vm.prank(random_executor);
        vm.expectRevert();
        entrypoint.handleOps(finalOps, payable(random_executor));

        assertEq(isContract(user1AccountAddress), false);
    }

    function test_createVerifyingUserOp_reuseNonce() public {
        bytes memory initCallData = abi.encodeWithSignature(
            "createAccount(address,uint256)",
            user1,
            0
        );
        bytes memory initCode = abi.encodePacked(
            abi.encodePacked(address(smart_account_factory)),
            initCallData
        );

        bytes memory paymasterAndDataWithSig;
        {
            uint128 post_op_gas = 100_000;
            uint256 exchange_rate = 58000 * 1e18;
            uint48 validUntil = uint48(block.timestamp) + 60 * 30;
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
                0, // nonce starts at 0
                bytes(""),
                user1AccountAddress,
                paymasterAndDataBeforeSig
            );
            UserOperation memory userOp = userOps[0];
            bytes32 verifyHash = bic.getHash(bic.VERIFYING_MODE(), userOp);
            bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
                verifyHash
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(dev_private_key, msgHash);

            paymasterAndDataWithSig = abi.encodePacked(
                address(bic),
                bic.VERIFYING_MODE(),
                validUntil,
                validAfter,
                post_op_gas,
                exchange_rate,
                r,
                s,
                v
            );
        }

        // First Operation - should succeed
        UserOperation[] memory firstOps = _setupUserOpExecute(
            user1_pkey,
            initCode,
            address(0),
            0,
            bytes(""),
            user1AccountAddress,
            paymasterAndDataWithSig
        );

        vm.prank(random_executor);
        entrypoint.handleOps(firstOps, payable(random_executor));

        assertEq(isContract(user1AccountAddress), true);

        // Attempt to reuse the same nonce (0)
        UserOperation[] memory secondOps = _setupUserOpExecute(
            user1_pkey,
            initCode,
            address(0),
            0, // Reusing nonce 0
            bytes(""),
            user1AccountAddress,
            paymasterAndDataWithSig
        );

        vm.prank(random_executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOp.selector,
                0,
                "AA10 sender already constructed"
            )
        );
        entrypoint.handleOps(secondOps, payable(random_executor));
    }

    function test_createOracleUserOp_noOracle() public {
        bytes memory initCallData = abi.encodeWithSignature(
            "createAccount(address,uint256)",
            user1,
            0
        );
        bytes memory initCode = abi.encodePacked(
            abi.encodePacked(address(smart_account_factory)),
            initCallData
        );

        UserOperation[] memory userOps = _setupUserOpExecute(
            user1_pkey,
            initCode,
            address(0),
            0,
            bytes(""),
            user1AccountAddress,
            abi.encodePacked(address(bic), bic.ORACLE_MODE())
        );

        vm.prank(random_executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOp.selector,
                0,
                "AA33 reverted: TokenSingletonPaymaster: no oracle"
            )
        );
        entrypoint.handleOps(userOps, payable(random_executor));

        assertEq(isContract(user1AccountAddress), false);
    }

    function test_createVerifyingUserOp_missingInitCode() public {
        // Missing initCode
        bytes memory initCode = bytes("");

        bytes memory paymasterAndDataWithSig;
        {
            uint128 post_op_gas = 100_000;
            uint256 exchange_rate = 58000 * 1e18;
            uint48 validUntil = uint48(block.timestamp) + 60 * 30;
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
                initCode, // Missing initCode
                address(0),
                0,
                bytes(""),
                user1AccountAddress,
                paymasterAndDataBeforeSig
            );
            UserOperation memory userOp = userOps[0];
            bytes32 verifyHash = bic.getHash(bic.VERIFYING_MODE(), userOp);
            bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
                verifyHash
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(dev_private_key, msgHash);

            paymasterAndDataWithSig = abi.encodePacked(
                address(bic),
                bic.VERIFYING_MODE(),
                validUntil,
                validAfter,
                post_op_gas,
                exchange_rate,
                r,
                s,
                v
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
        vm.expectRevert();
        entrypoint.handleOps(finalOps, payable(random_executor));

        assertEq(isContract(user1AccountAddress), false);
    }

    function test_createVerifyingUserOp_whenPaused() public {
        // Pause the paymaster
        vm.prank(owner);
        bic.pause();

        bytes memory initCallData = abi.encodeWithSignature(
            "createAccount(address,uint256)",
            user1,
            0
        );
        bytes memory initCode = abi.encodePacked(
            abi.encodePacked(address(smart_account_factory)),
            initCallData
        );

        bytes memory paymasterAndDataWithSig;
        {
            uint128 post_op_gas = 100_000;
            uint256 exchange_rate = 58000 * 1e18;
            uint48 validUntil = uint48(block.timestamp) + 60 * 30;
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
            bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
                verifyHash
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(dev_private_key, msgHash);

            paymasterAndDataWithSig = abi.encodePacked(
                address(bic),
                bic.VERIFYING_MODE(),
                validUntil,
                validAfter,
                post_op_gas,
                exchange_rate,
                r,
                s,
                v
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

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOp.selector,
                0,
                "AA50 postOp reverted: B: paused transfer"
            )
        );
        entrypoint.handleOps(finalOps, payable(random_executor));
    }

    function test_createVerifyingUserOp_batchOperations() public {
        // Create multiple user accounts and their private keys
        address[] memory users = new address[](3);
        uint256[] memory userKeys = new uint256[](3);
        address[] memory userAccounts = new address[](3);

        for (uint i = 0; i < 3; i++) {
            userKeys[i] = 0x100 + i;
            users[i] = vm.addr(userKeys[i]);
            // Get the counterfactual address using the factory's getAddress
            userAccounts[i] = smart_account_factory.getAddress(users[i], 0);

            // Fund each account with BIC tokens
            vm.prank(owner);
            bic.transfer(userAccounts[i], user1_init_amount);
        }

        UserOperation[] memory ops = new UserOperation[](3);
        bytes memory paymasterAndDataWithSig;

        // Setup common parameters for all operations
        uint128 post_op_gas = 100_000;
        uint256 exchange_rate = 58000 * 1e18;
        uint48 validUntil = uint48(block.timestamp) + 60 * 30;
        uint48 validAfter = uint48(block.timestamp) - 1;

        // Create batch of operations
        for (uint i = 0; i < 3; i++) {
            bytes memory initCallData = abi.encodeWithSignature(
                "createAccount(address,uint256)",
                users[i],
                0
            );
            bytes memory initCode = abi.encodePacked(
                abi.encodePacked(address(smart_account_factory)),
                initCallData
            );

            bytes memory paymasterAndDataBeforeSig = abi.encodePacked(
                address(bic),
                bic.VERIFYING_MODE(),
                validUntil,
                validAfter,
                post_op_gas,
                exchange_rate
            );

            UserOperation[] memory tempOps = _setupUserOpExecute(
                userKeys[i],
                initCode,
                address(0),
                0,
                bytes(""),
                userAccounts[i],
                paymasterAndDataBeforeSig
            );

            UserOperation memory userOp = tempOps[0];
            bytes32 verifyHash = bic.getHash(bic.VERIFYING_MODE(), userOp);
            bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
                verifyHash
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(dev_private_key, msgHash);

            paymasterAndDataWithSig = abi.encodePacked(
                address(bic),
                bic.VERIFYING_MODE(),
                validUntil,
                validAfter,
                post_op_gas,
                exchange_rate,
                r,
                s,
                v
            );

            ops[i] = _setupUserOpExecute(
                userKeys[i],
                initCode,
                address(0),
                0,
                bytes(""),
                userAccounts[i],
                paymasterAndDataWithSig
            )[0];
        }

        // Log some debug info
        console.log("First account address:", userAccounts[0]);
        console.log("First account initCode length:", ops[0].initCode.length);
        console.log("First account sender:", ops[0].sender);

        // Execute batch of operations
        vm.prank(random_executor);
        entrypoint.handleOps(ops, payable(random_executor));

        // Verify all accounts were created successfully
        for (uint i = 0; i < 3; i++) {
            assertTrue(
                isContract(userAccounts[i]),
                string.concat("Account ", vm.toString(i), " was not created")
            );

            // Verify each account is properly initialized
            SimpleAccount account = SimpleAccount(payable(userAccounts[i]));
            assertEq(
                account.owner(),
                users[i],
                string.concat("Account ", vm.toString(i), " has wrong owner")
            );
        }

        // Try to create the same accounts again (should fail due to nonce)
        vm.prank(random_executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOp.selector,
                0,
                "AA10 sender already constructed"
            )
        );
        entrypoint.handleOps(ops, payable(random_executor));
    }

    function test_createVerifyingUserOp_highGasPrice() public {
        bytes memory initCallData = abi.encodeWithSignature(
            "createAccount(address,uint256)",
            user1,
            0
        );
        bytes memory initCode = abi.encodePacked(
            abi.encodePacked(address(smart_account_factory)),
            initCallData
        );

        // Set reasonable basefee for the block
        vm.fee(30 gwei);

        bytes memory paymasterAndDataWithSig;
        {
            uint128 post_op_gas = 100_000;
            uint256 exchange_rate = 58000 * 1e18;
            uint48 validUntil = uint48(block.timestamp) + 60 * 30;
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

            // Set gas values according to EntryPoint's expectations
            userOps[0].maxFeePerGas = 31 gwei; // Just above max allowed
            userOps[0].maxPriorityFeePerGas = 2 gwei; // Normal priority fee
            userOps[0].preVerificationGas = 21000; // Normal pre-verification gas
            userOps[0].verificationGasLimit = 100000; // Normal verification gas limit
            userOps[0].callGasLimit = 100000; // Normal call gas limit

            UserOperation memory userOp = userOps[0];
            bytes32 verifyHash = bic.getHash(bic.VERIFYING_MODE(), userOp);
            bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
                verifyHash
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(dev_private_key, msgHash);

            paymasterAndDataWithSig = abi.encodePacked(
                address(bic),
                bic.VERIFYING_MODE(),
                validUntil,
                validAfter,
                post_op_gas,
                exchange_rate,
                r,
                s,
                v
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

        // Set maxFeePerGas just above the EntryPoint's limit
        finalOps[0].maxFeePerGas = 31 gwei;
        finalOps[0].maxPriorityFeePerGas = 2 gwei;
        finalOps[0].preVerificationGas = 21000;
        finalOps[0].verificationGasLimit = 100000;
        finalOps[0].callGasLimit = 100000;

        vm.prank(random_executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOp.selector,
                0,
                "AA13 initCode failed or OOG"
            )
        );
        entrypoint.handleOps(finalOps, payable(random_executor));

        assertEq(isContract(user1AccountAddress), false);
    }

    function test_useTokenToPayGas() public {
        // Close pre-public phase first
        vm.prank(owner);
        bic.setPrePublic(false);

        // First create the account
        bytes memory initCallData = abi.encodeWithSignature(
            "createAccount(address,uint256)",
            user1,
            0
        );
        bytes memory initCode = abi.encodePacked(
            abi.encodePacked(address(smart_account_factory)),
            initCallData
        );

        // Create account using verifying mode
        bytes memory paymasterAndDataWithSig;
        {
            uint128 post_op_gas = 100_000;
            uint256 exchange_rate = 58000 * 1e18;
            uint48 validUntil = uint48(block.timestamp) + 60 * 30;
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
            bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
                verifyHash
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(dev_private_key, msgHash);

            paymasterAndDataWithSig = abi.encodePacked(
                address(bic),
                bic.VERIFYING_MODE(),
                validUntil,
                validAfter,
                post_op_gas,
                exchange_rate,
                r,
                s,
                v
            );
        }

        UserOperation[] memory createOps = _setupUserOpExecute(
            user1_pkey,
            initCode,
            address(0),
            0,
            bytes(""),
            user1AccountAddress,
            paymasterAndDataWithSig
        );

        vm.prank(random_executor);
        entrypoint.handleOps(createOps, payable(random_executor));
        assertEq(isContract(user1AccountAddress), true);

        // Now test using BIC to pay for gas
        // Record initial BIC balance
        uint256 initialBicBalance = bic.balanceOf(user1AccountAddress);

        // Create a transfer operation using the created account
        address recipient = address(0x123);
        uint256 transferAmount = 1 ether;
        bytes memory transferCallData = abi.encodeWithSignature(
            "transfer(address,uint256)",
            recipient,
            transferAmount
        );

        // Setup UserOp for transfer
        bytes memory transferPaymasterAndDataWithSig;
        {
            uint128 post_op_gas = 100_000;
            uint256 exchange_rate = 58000 * 1e18;
            uint48 validUntil = uint48(block.timestamp) + 60 * 30;
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
                "", // Empty initCode as account exists
                address(bic),
                0,
                transferCallData,
                user1AccountAddress,
                paymasterAndDataBeforeSig
            );
            UserOperation memory userOp = userOps[0];
            bytes32 verifyHash = bic.getHash(bic.VERIFYING_MODE(), userOp);
            bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
                verifyHash
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(dev_private_key, msgHash);

            transferPaymasterAndDataWithSig = abi.encodePacked(
                address(bic),
                bic.VERIFYING_MODE(),
                validUntil,
                validAfter,
                post_op_gas,
                exchange_rate,
                r,
                s,
                v
            );
        }

        UserOperation[] memory transferOps = _setupUserOpExecute(
            user1_pkey,
            "", // Empty initCode
            address(bic),
            0,
            transferCallData,
            user1AccountAddress,
            transferPaymasterAndDataWithSig
        );

        // Execute transfer operation
        vm.prank(random_executor);
        entrypoint.handleOps(transferOps, payable(random_executor));

        // Verify transfer was successful and gas was paid in BIC
        assertEq(
            bic.balanceOf(recipient),
            transferAmount,
            "Transfer amount incorrect"
        );
        (initialBicBalance - transferAmount, "less");
        assertTrue(
            bic.balanceOf(user1AccountAddress) <
                initialBicBalance - transferAmount,
            "Gas was not paid in BIC tokens"
        );
    }
}
