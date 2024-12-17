// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// import "@account-abstraction/contracts/samples/SimpleAccountFactory.sol";
// import {BicTokenPaymasterTestBase} from "../BicTokenPaymasterTestBase.sol";

// contract TestPaymaster is BicTokenPaymasterTestBase {
//     SimpleAccountFactory smart_account_factory;
//     uint256 user1_pkey = 0x001;
//     address user1 = vm.addr(user1_pkey);
//     uint256 public user1_init_amount = 10000 * 1e18;

//     address public randomExecutor = address(0xeee);

//     function setUp() public virtual override {
//         super.setUp();
//         smart_account_factory = new SimpleAccountFactory(entrypoint);
//         bic.deposit{value: 1*1e18}();
//         vm.prank(owner);
//         bic.transfer(user1, user1_init_amount);
//     }

//     function _setupUserOp(
//         uint256 _signerPKey,
//         bytes memory _initCode,
//         bytes memory _callDataForEntrypoint,
//         address sender,
//         bytes memory _paymasterAndData
//     ) internal returns (UserOperation[] memory ops) {
//         uint256 nonce = entrypoint.getNonce(sender, 0);

//         // Get user op fields
//         UserOperation memory op = UserOperation({
//             sender: sender,
//             nonce: nonce,
//             initCode: _initCode,
//             callData: _callDataForEntrypoint,
//             callGasLimit: 500_000,
//             verificationGasLimit: 500_000,
//             preVerificationGas: 500_000,
//             maxFeePerGas: 500_000,
//             maxPriorityFeePerGas: 500_000,
//             paymasterAndData: _paymasterAndData,
//             signature: bytes("")
//         });

//         // Sign UserOp
//         bytes32 opHash = entrypoint.getUserOpHash(op);
//         bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(opHash);

//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPKey, msgHash);
//         bytes memory userOpSignature = abi.encodePacked(r, s, v);

//         op.signature = userOpSignature;

//         // Store UserOp
//         ops = new UserOperation[](1);
//         ops[0] = op;
//     }

//     function _setupUserOpExecute(
//         uint256 _signerPKey,
//         bytes memory _initCode,
//         address _target,
//         uint256 _value,
//         bytes memory _callData,
//         address sender,
//         bytes memory _paymasterAndData
//     ) internal returns (UserOperation[] memory) {
//         bytes memory callDataForEntrypoint = abi.encodeWithSignature(
//             "execute(address,uint256,bytes)",
//             _target,
//             _value,
//             _callData
//         );

//         return _setupUserOp(_signerPKey, _initCode, callDataForEntrypoint, sender, _paymasterAndData);
//     }

//     function _setupUserOpExecuteBatch(
//         uint256 _signerPKey,
//         bytes memory _initCode,
//         address[] memory _target,
//         uint256[] memory _value,
//         bytes[] memory _callData,
//         address sender,
//         bytes memory _paymasterAndData
//     ) internal returns (UserOperation[] memory) {
//         bytes memory callDataForEntrypoint = abi.encodeWithSignature(
//             "executeBatch(address[],uint256[],bytes[])",
//             _target,
//             _value,
//             _callData
//         );

//         return _setupUserOp(_signerPKey, _initCode, callDataForEntrypoint, sender, _paymasterAndData);
//     }

// }
