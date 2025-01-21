// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "../interfaces/PaymasterErrors.sol";
import "./MultiSigner.sol";
import "./Treasury.sol";
import "@account-abstraction/contracts/core/BasePaymaster.sol";
import "@account-abstraction/contracts/core/Helpers.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/samples/IOracle.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract TokenSingletonPaymaster is
    BasePaymaster,
    ERC20Votes,
    MultiSigner,
    PaymasterErrors,
    Treasury
{
    /// The factory that creates accounts. used to validate account creation. Just to make sure not have any unexpected account creation trying to bug the system
    mapping(address => bool) public factories;

    /// The oracle to use for token exchange rate.
    address public oracle;

    /// Calculated cost of the postOp, minimum value that need verificationGasLimit to be higher than
    uint256 public COST_OF_POST = 60000;

    uint256 public PAYMASTER_DATA_OFFSET = 20;

    /// @notice Mode indicating that the Paymaster is in Oracle mode.
    uint8 public ORACLE_MODE = 0;

    /// @notice Mode indicating that the Paymaster is in Verifying mode.
    uint8 public VERIFYING_MODE = 1;

    /// @notice The length of the ERC-20 config without singature.
    uint8 public VERIFYING_PAYMASTER_DATA_LENGTH = 60;

    /// @dev Emitted when a user is charged, using for indexing on subgraph
    event ChargeFee(bytes32 indexed userOpHash, address sender, uint256 fee);

    /// @dev Emitted when the oracle is set
    event SetOracle(
        address oldOracle,
        address newOracle,
        address indexed _operator
    );

    /// @dev Emitted when a factory is added
    event AddFactory(address factory, address indexed _operator);

    /// @notice Hold all configs needed in ERC-20 mode.
    struct VerifyingPaymasterData {
        /// @dev Timestamp until which the sponsorship is valid.
        uint48 validUntil;
        /// @dev Timestamp after which the sponsorship is valid.
        uint48 validAfter;
        /// @dev The gas overhead of calling transferFrom during the postOp.
        uint128 postOpGas;
        /// @dev The exchange rate of the ERC-20 token during sponsorship.
        uint256 exchangeRate;
        /// @dev The paymaster signature.
        bytes signature;
    }

    /// @notice Holds all context needed during the EntryPoint's postOp call.
    struct PostOpContext {
        /// @dev The userOperation sender.
        address sender;
        /// @dev The exchange rate between the token and the chain's native currency.
        uint256 exchangeRate;
        /// @dev The gas overhead when performing the transferFrom call.
        uint128 postOpGas;
        /// @dev The userOperation hash.
        bytes32 userOpHash;
        /// @dev The userOperation's maxFeePerGas (v0.6 only)
        uint256 maxFeePerGas;
        /// @dev The userOperation's maxPriorityFeePerGas (v0.6 only)
        uint256 maxPriorityFeePerGas;
    }

    constructor (
        address _entryPoint,
        address[] memory _signers
    )  BasePaymaster(IEntryPoint(_entryPoint)) MultiSigner(_signers)  {}

    /**
     * @notice Set the oracle to use for token exchange rate.
     * @param _oracle the oracle to use.
     */
    function setOracle(address _oracle) external onlyOwner {
        emit SetOracle(oracle, _oracle, msg.sender);
        oracle = _oracle;
    }

    /**
     * @notice Add a factory that creates accounts.
     * @param _factory the factory to add.
     */
    function addFactory(address _factory) external onlyOwner {
        factories[_factory] = true;
        emit AddFactory(_factory, msg.sender);
    }

    /**
     * @notice Transfer paymaster ownership.
     * owner of this paymaster is allowed to withdraw funds (tokens transferred to this paymaster's balance)
     * when changing owner, the old owner's withdrawal rights are revoked.
     * @param newOwner the new owner of the paymaster.
     */
    function transferOwnership(
        address newOwner
    ) public virtual override onlyOwner {
        // remove allowance of current owner
        _approve(address(this), owner(), 0);
        super.transferOwnership(newOwner);
        // new owner is allowed to withdraw tokens from the paymaster's balance
        _approve(address(this), newOwner, type(uint).max);
    }

    /**
     * @notice Token to eth exchange rate.
     * @param valueEth the value in eth to convert to tokens.
     * @return valueToken the value in tokens.
     */
    function getTokenValueOfEth(
        uint256 valueEth
    ) internal view virtual returns (uint256 valueToken) {
        
        return IOracle(oracle).getTokenValueOfEth(valueEth);
    }

    /**
     * @notice Validate the request:
     *
     * - If this is a constructor call, make sure it is a known account.
     * - Verify the sender has enough tokens.
     * @dev (since the paymaster is also the token, there is no notion of "approval")
     * @param userOp the user operation to validate.
     * @param requiredPreFund the required pre-fund for the operation.
     * @return context the context to pass to postOp.
     * @return validationData the validation data.
     */
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 requiredPreFund
    )
        internal
        view
        override
        returns (bytes memory context, uint256 validationData)
    {
        (uint8 mode, bytes calldata paymasterConfig) = _parsePaymasterAndData(
            userOp.paymasterAndData,
            PAYMASTER_DATA_OFFSET
        );

        if (mode == ORACLE_MODE) {
            return _validateOracleMode(userOp, requiredPreFund, userOpHash);
        } else if (mode == VERIFYING_MODE) {
            return _validateVerifyingMode(userOp, paymasterConfig, userOpHash);
        } else {
            revert PaymasterInvalidVerifyingMode(mode);
        }
    }
    /**
     * @notice Parses the userOperation's paymasterAndData field and returns the paymaster mode and encoded paymaster configuration bytes.
     * @dev _paymasterDataOffset should have value 20 for V6 and 52 for V7.
     * @param _paymasterAndData The paymasterAndData to parse.
     * @param _paymasterDataOffset The paymasterData offset in paymasterAndData.
     * @return mode The paymaster mode.
     * @return paymasterConfig The paymaster config bytes.
     */
    function _parsePaymasterAndData(
        bytes calldata _paymasterAndData,
        uint256 _paymasterDataOffset
    ) internal pure returns (uint8, bytes calldata) {
        if (
            _paymasterAndData.length <= _paymasterDataOffset
        ) {
            revert PaymasterDataLength(_paymasterAndData.length, _paymasterDataOffset);
        }

        uint8 mode = uint8(
            bytes1(
                _paymasterAndData[_paymasterDataOffset:_paymasterDataOffset + 1]
            )
        );
        bytes
            calldata paymasterConfig = _paymasterAndData[_paymasterDataOffset +
                1:];

        return (mode, paymasterConfig);
    }

    /**
     * @notice Validate the constructor code and parameters.
     * @dev When constructing an account, validate constructor code and parameters
     * @dev We trust our factory (and that it doesn't have any other public methods)
     * @param _userOp the user operation to validate.
     */
    function _validateConstructor(
        UserOperation calldata _userOp
    ) internal view virtual {
        address factory = address(bytes20(_userOp.initCode[0:20]));
        
        if (
            !factories[factory]
        ) {
            revert PaymasterInvalidFactory(factory);
        }
    }

    function _validateOracleMode(
        UserOperation calldata _userOp,
        uint256 _requiredPreFund,
        bytes32 _userOpHash
    ) internal view returns (bytes memory, uint256) {
        
        if (oracle == address(0)) {
            revert PaymasterInvalidOracle(oracle);
        }
        uint256 tokenPrefund = getTokenValueOfEth(_requiredPreFund);

        // verificationGasLimit is dual-purposed, as gas limit for postOp. make sure it is high enough
        // make sure that verificationGasLimit is high enough to handle postOp
        if (
            _userOp.verificationGasLimit <= COST_OF_POST
        ) {
            revert PaymasterLowGasPostOp(_userOp.verificationGasLimit);
        }

        if (_userOp.initCode.length != 0) {
            _validateConstructor(_userOp);
        } 
        
        if (balanceOf(_userOp.sender) < tokenPrefund) {
            revert PaymasterInsufficient(_userOp.sender, tokenPrefund);
        }
        
        return (
            _createPostOpContext(
                _userOp,
                getTokenValueOfEth(1e18),
                0,
                _userOpHash
            ),
            0
        );
    }

    /**
     * @notice Internal helper to validate the paymasterAndData when used in verifying mode.
     * @param _userOp The userOperation.
     * @param _paymasterConfig The encoded paymaster config taken from paymasterAndData.
     * @param _userOpHash The userOperation hash.
     * @return (context, validationData) The validation data to return to the EntryPoint.
     */
    function _validateVerifyingMode(
        UserOperation calldata _userOp,
        bytes calldata _paymasterConfig,
        bytes32 _userOpHash
    ) internal view returns (bytes memory, uint256) {
        if (
            _paymasterConfig.length < VERIFYING_PAYMASTER_DATA_LENGTH
        ) {
            revert PaymasterVerifyingModeDataLength(_paymasterConfig.length);
        }

        uint48 validUntil = uint48(bytes6(_paymasterConfig[0:6]));
        uint48 validAfter = uint48(bytes6(_paymasterConfig[6:12]));
        uint128 postOpGas = uint128(bytes16(_paymasterConfig[12:28]));
        uint256 exchangeRate = uint256(bytes32(_paymasterConfig[28:60]));
        bytes calldata signature = _paymasterConfig[60:];

        if (
            exchangeRate == 0
        ) {
            revert PaymasterExchangeRate(exchangeRate);
        }

        if (
            signature.length != 64 && signature.length != 65
        ) {
            revert PaymasterUnauthorizedVerifying();
        }

        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(
            getHash(VERIFYING_MODE, _userOp)
        );

        bool isSignatureValid = signers[ECDSA.recover(hash, signature)];
        uint256 validationData = _packValidationData(
            !isSignatureValid,
            validUntil,
            validAfter
        );

        return (
            _createPostOpContext(_userOp, exchangeRate, postOpGas, _userOpHash),
            validationData
        );
    }

    /**
     * @notice Helper function to encode the postOp context data for V6 userOperations.
     * @param _userOp The userOperation.
     * @param _exchangeRate The token exchange rate.
     * @param _postOpGas The gas to cover the overhead of the postOp transferFrom call.
     * @param _userOpHash The userOperation hash.
     * @return bytes memory The encoded context.
     */
    function _createPostOpContext(
        UserOperation calldata _userOp,
        uint256 _exchangeRate,
        uint128 _postOpGas,
        bytes32 _userOpHash
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                PostOpContext({
                    sender: _userOp.sender,
                    exchangeRate: _exchangeRate,
                    postOpGas: _postOpGas,
                    userOpHash: _userOpHash,
                    maxFeePerGas: _userOp.maxFeePerGas,
                    maxPriorityFeePerGas: _userOp.maxPriorityFeePerGas
                })
            );
    }

    /**
     * @notice Actual charge of user.
     * @dev This method will be called just after the user's TX with mode==OpSucceeded|OpReverted (account pays in both cases)
     * @param mode the mode of the operation.
     * @param context the context to pass to postOp.
     * @param actualGasCost the actual gas cost of the operation.
     */
    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) internal override {
        //we don't really care about the mode, we just pay the gas with the user's token.
        (mode);

        (
            address sender,
            uint256 exchangeRate,
            uint128 postOpGas,
            bytes32 userOpHash,
            uint256 maxFeePerGas,
            uint256 maxPriorityFeePerGas
        ) = _parsePostOpContext(context);

        uint256 actualUserOpFeePerGas;
        if (maxFeePerGas == maxPriorityFeePerGas) {
            // chains that only support legacy (pre EIP-1559 transactions)
            actualUserOpFeePerGas = maxFeePerGas;
        } else {
            actualUserOpFeePerGas = Math.min(
                maxFeePerGas,
                maxPriorityFeePerGas + block.basefee
            );
        }

        uint256 costInToken = getCostInToken(
            actualGasCost,
            postOpGas,
            actualUserOpFeePerGas,
            exchangeRate
        );

        _transfer(sender, treasury, costInToken);

        emit ChargeFee(userOpHash, sender, costInToken);
    }

    function _parsePostOpContext(
        bytes calldata _context
    )
        internal
        pure
        returns (address, uint256, uint128, bytes32, uint256, uint256)
    {
        PostOpContext memory ctx = abi.decode(_context, (PostOpContext));

        return (
            ctx.sender,
            ctx.exchangeRate,
            ctx.postOpGas,
            ctx.userOpHash,
            ctx.maxFeePerGas,
            ctx.maxPriorityFeePerGas
        );
    }

    /**
     * @notice Gets the cost in amount of tokens.
     * @param _actualGasCost The gas consumed by the userOperation.
     * @param _postOpGas The gas overhead of transfering the ERC-20 when making the postOp payment.
     * @param _actualUserOpFeePerGas The actual gas cost of the userOperation.
     * @param _exchangeRate The token exchange rate - how many tokens one full ETH (1e18 wei) is worth.
     * @return uint256 The gasCost in token units.
     */
    function getCostInToken(
        uint256 _actualGasCost,
        uint256 _postOpGas,
        uint256 _actualUserOpFeePerGas,
        uint256 _exchangeRate
    ) public pure returns (uint256) {
        return
            ((_actualGasCost + (_postOpGas * _actualUserOpFeePerGas)) *
                _exchangeRate) / 1e18;
    }

    /**
     * @notice Hashses the userOperation data when used in verifying mode.
     * @param _userOp The user operation data.
     * @param _mode The mode that we want to get the hash for.
     * @return bytes32 The hash that the signer should sign over.
     */
    function getHash(
        uint8 _mode,
        UserOperation calldata _userOp
    ) public view returns (bytes32) {
        if (_mode == VERIFYING_MODE) {
            return _getHash(_userOp, VERIFYING_PAYMASTER_DATA_LENGTH);
        } else {
            return bytes32(0);
        }
    }

    /**
     * @notice Internal helper that hashes the user operation data.
     * @dev We hash over all fields in paymasterAndData but the paymaster signature.
     * @param paymasterDataLength The paymasterData length.
     * @return bytes32 The hash that the signer should sign over.
     */
    function _getHash(
        UserOperation calldata _userOp,
        uint256 paymasterDataLength
    ) internal view returns (bytes32) {
        bytes32 userOpHash = keccak256(
            abi.encode(
                _userOp.sender,
                _userOp.nonce,
                _userOp.callGasLimit,
                _userOp.verificationGasLimit,
                _userOp.preVerificationGas,
                _userOp.maxFeePerGas,
                _userOp.maxPriorityFeePerGas,
                keccak256(_userOp.callData),
                keccak256(_userOp.initCode),
                // hashing over all paymaster fields besides signature
                keccak256(
                    _userOp.paymasterAndData[:PAYMASTER_DATA_OFFSET +
                        paymasterDataLength]
                )
            )
        );

        return keccak256(abi.encode(userOpHash, block.chainid, address(this)));
    }
}
