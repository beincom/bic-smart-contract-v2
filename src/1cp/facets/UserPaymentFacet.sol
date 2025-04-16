// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import { LibAccess } from "../libraries/LibAccess.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";
import { Initializable } from "../utils/Initializable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UserPaymentFacet is Initializable {
    using SafeERC20 for IERC20;
    // Struct
    struct UserPaymentStorage {
        uint256 bufferPostOp;
        address userTreasury;
        address paymentToken;
    }

    /// Errors
    error ZeroPayment();
    error ZeroAddress();

    /// Storage
    uint256 internal constant DENOMINATOR = 1e10;
    bytes32 internal constant USER_CONFIG_STORAGE_POSITION = keccak256("1CP.user.config.storage");

    /// Events
    event InitializedUserPaymentConfig(
        address treasury,
        address paymentToken,
        uint256 bufferPostOp
    );
    event UserTreasuryUpdated(address updater, address newTreasury);
    event PaymentTokenUpdated(address updater, address newPaymentToken);
    event BufferPostOpUpdated(address updater, uint256 bufferPostOp);
    event AccountBought(
        address token,
        address from,
        address to,
        uint256 amount,
        string orderId
    );
    event CallBuyAccount(
        address caller,
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 fee,
        string orderId
    );

    /// @notice Get user config storage
    function getUserPaymentStorage() external pure returns (
        uint256 bufferPostOp,
        address userTreasury,
        address paymentToken
    ) {
        UserPaymentStorage memory s = getStorage();
        return (s.bufferPostOp, s.userTreasury, s.paymentToken);
    }

    /**
     * @notice Initialize user payment config
     * @param treasury the user treasury address
     * @param paymentToken The payment token address used for reimbursing gas fee via callBuyAccount
     * @param bufferPostOp The additional gas used for additional execution via callBuyAccount
     */
    function initializeUserPaymentConfig(
        address treasury,
        address paymentToken,
        uint256 bufferPostOp
    ) external initializer {
        LibDiamond.enforceIsContractOwner();
        if (treasury == address(0) || paymentToken == address(0)) {
            revert ZeroAddress();
        }
        
        UserPaymentStorage storage s = getStorage();
        s.userTreasury = treasury;
        s.paymentToken = paymentToken;
        s.bufferPostOp = bufferPostOp;
        emit InitializedUserPaymentConfig(treasury, paymentToken, bufferPostOp);
    }

    /// @notice Update user treasury address
    /// @param newTreasury The new user treasury address
    function updateUserTreasury(address newTreasury) external {
        LibDiamond.enforceIsContractOwner();
        if (newTreasury == address(0)) {
            revert ZeroAddress();
        }
        UserPaymentStorage storage s = getStorage();
        s.userTreasury = newTreasury;
        emit UserTreasuryUpdated(msg.sender, newTreasury);
    }

    /// @notice Update user payment token address
    /// @param paymentToken The payment token address used for reimbursing gas fee via callBuyAccount
    function updateUserPaymentToken(address paymentToken) external {
        LibDiamond.enforceIsContractOwner();
        if (paymentToken == address(0)) {
            revert ZeroAddress();
        }
        UserPaymentStorage storage s = getStorage();
        s.paymentToken = paymentToken;
        emit PaymentTokenUpdated(msg.sender, paymentToken);
    }

    /// @notice Update buffer gas for post ops
    /// @param bufferPostOp The additional gas used for additional execution via callBuyAccount
    function updateUserBufferPostOp(uint256 bufferPostOp) external {
        LibDiamond.enforceIsContractOwner();
        UserPaymentStorage storage s = getStorage();
        s.bufferPostOp = bufferPostOp;
        emit BufferPostOpUpdated(msg.sender, bufferPostOp);
    }

    /**
     * @notice Buy a specific premium account
     * @param token The payment token
     * @param to The seller adderss
     * @param amount The selling amount
     * @param orderId The off-chain orderId based on services
     */
    function buyAccount(
        address token,
        address to,
        uint256 amount,
        string memory orderId
    ) external {
        if (amount == 0) {
            revert ZeroPayment();
        }
        UserPaymentStorage storage s = getStorage();
        IERC20(token).safeTransferFrom(msg.sender, s.userTreasury, amount);

        emit AccountBought(token, msg.sender, s.userTreasury, amount, orderId);
    }

    /**
     * @notice Buy a specific premium account via callers
     * @param token The payment token
     * @param from The buyer address
     * @param to The seller address
     * @param amount The selling amount
     * @param orderId The off-chain orderId based on services
     * @param maxFeePerGas The maximum fee per a gas unit
     * @param maxPriorityFeePerGas The maximum priority fee per a gas unit
     * @param paymentPrice The exchanged ratio of payment token and native gas token
     * @return The actual gas cost
     * @return The actual payment cost
     */
    function callBuyAccount(
        address token,
        address from,
        address to,
        uint256 amount,
        string memory orderId,
        uint256 maxFeePerGas,
        uint256 maxPriorityFeePerGas,
        uint256 paymentPrice
    ) external returns (uint256, uint256) {
        uint256 preGas = gasleft();
        LibAccess.enforceAccessControl();
        if (amount == 0) {
            revert ZeroPayment();
        }
        UserPaymentStorage storage s = getStorage();
        IERC20(token).safeTransferFrom(from, s.userTreasury, amount);
        
        uint256 gasPrice = getUserOpGasPrice(maxFeePerGas, maxPriorityFeePerGas);
        uint256 actualGas = preGas - gasleft() + s.bufferPostOp;
        uint256 actualGasCost = actualGas * gasPrice;
        uint256 actualPaymentCost = actualGasCost * paymentPrice / DENOMINATOR;
        
        IERC20(s.paymentToken).safeTransferFrom(from, s.userTreasury, actualPaymentCost);
        emit CallBuyAccount(
            msg.sender,
            token,
            from,
            s.userTreasury,
            amount,
            actualPaymentCost,
            orderId
        );
        return (actualGasCost, actualPaymentCost);
    }

    /// @notice Get storage position of user configuration
    function getStorage() internal pure returns (UserPaymentStorage storage dc) {
        bytes32 position = USER_CONFIG_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            dc.slot := position
        }
    }

    /// The gas price this UserOp agrees to pay.
    /// relayer/block builder might submit the TX with higher priorityFee, but the user should not
    function getUserOpGasPrice(uint256 maxFeePerGas, uint256 maxPriorityFeePerGas) internal view returns (uint256) {
        unchecked {
            if (maxFeePerGas == maxPriorityFeePerGas) {
                //legacy mode (for networks that don't support basefee opcode)
                return maxFeePerGas;
            }
            return min(maxFeePerGas, maxPriorityFeePerGas + block.basefee);
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
