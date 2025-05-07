// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import { LibAccess } from "../libraries/LibAccess.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LuckyWheelFacet {
    using SafeERC20 for IERC20;
    // Struct
    struct LuckyWheelStorage {
        uint8 initialLuckyWheelConfig;
        uint256 bufferPostOp;
        address luckyWheelTreasury;
        address paymentToken;
    }

    /// Errors
    error ZeroPayment();
    error ZeroAddress();
    error AlreadyInitialized();

    /// Storage
    uint256 internal constant DENOMINATOR = 1e10;
    bytes32 internal constant LUCKY_WHEEL_CONFIG_STORAGE_POSITION = keccak256("1CP.lucky.wheel.config.storage");

    /// Events
    event InitializedLuckyWheelConfig(
        address treasury,
        address paymentToken,
        uint256 bufferPostOp
    );
    event LuckyWheelTreasuryUpdated(address updater, address newTreasury);
    event PaymentTokenUpdated(address updater, address newPaymentToken);
    event BufferPostOpUpdated(address updater, uint256 bufferPostOp);
    event LuckyWheelBought(
        address token,
        address from,
        address to,
        uint256 amount,
        string orderId
    );
    event CallBuyLuckyWheel(
        address caller,
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 fee,
        string orderId
    );

    modifier initializer() {
        LuckyWheelStorage storage s = getStorage();
        if (s.initialLuckyWheelConfig != 0) {
            revert AlreadyInitialized();
        }
        s.initialLuckyWheelConfig = 1;
        _;
    }

    /// @notice Get lucky wheel storage
    function getLuckyWheelStorage() external pure returns (
        uint256 bufferPostOp,
        address luckyWheelTreasury,
        address paymentToken
    ) {
        LuckyWheelStorage memory s = getStorage();
        return (s.bufferPostOp, s.luckyWheelTreasury, s.paymentToken);
    }

    /**
     * @notice Initialize lucky wheel config
     * @param treasury the lucky wheel treasury address
     * @param paymentToken The payment token address used for reimbursing gas fee via callBuyLuckyWheel
     * @param bufferPostOp The additional gas used for additional execution via callBuyLuckyWheel
     */
    function initializeLuckyWheelConfig(
        address treasury,
        address paymentToken,
        uint256 bufferPostOp
    ) external initializer {
        LibDiamond.enforceIsContractOwner();
        if (treasury == address(0) || paymentToken == address(0)) {
            revert ZeroAddress();
        }

        LuckyWheelStorage storage s = getStorage();
        s.luckyWheelTreasury = treasury;
        s.paymentToken = paymentToken;
        s.bufferPostOp = bufferPostOp;
        emit InitializedLuckyWheelConfig(treasury, paymentToken, bufferPostOp);
    }

    /// @notice Update lucky wheel treasury address
    /// @param newTreasury The new lucky wheel treasury address
    function updateLuckyWheelTreasury(address newTreasury) external {
        LibDiamond.enforceIsContractOwner();
        if (newTreasury == address(0)) {
            revert ZeroAddress();
        }
        LuckyWheelStorage storage s = getStorage();
        s.luckyWheelTreasury = newTreasury;
        emit LuckyWheelTreasuryUpdated(msg.sender, newTreasury);
    }

    /// @notice Update content payment token address
    /// @param paymentToken The payment token address used for reimbursing gas fee via callBuyLuckyWheel
    function updateLuckyWheelPaymentToken(address paymentToken) external {
        LibDiamond.enforceIsContractOwner();
        if (paymentToken == address(0)) {
            revert ZeroAddress();
        }
        LuckyWheelStorage storage s = getStorage();
        s.paymentToken = paymentToken;
        emit PaymentTokenUpdated(msg.sender, paymentToken);
    }

    /// @notice Update buffer gas for post ops
    /// @param bufferPostOp The additional gas used for additional execution via callBuyLuckyWheel
    function updateLuckyWheelBufferPostOp(uint256 bufferPostOp) external {
        LibDiamond.enforceIsContractOwner();
        LuckyWheelStorage storage s = getStorage();
        s.bufferPostOp = bufferPostOp;
        emit BufferPostOpUpdated(msg.sender, bufferPostOp);
    }

    /**
     * @notice Buy a specific lucky wheel
     * @param token The payment token
     * @param to The seller adderss
     * @param amount The selling amount
     * @param orderId The off-chain orderId based on services
     */
    function buyLuckyWheel(
        address token,
        address to,
        uint256 amount,
        string memory orderId
    ) external {
        if (amount == 0) {
            revert ZeroPayment();
        }
        LuckyWheelStorage storage s = getStorage();
        IERC20(token).safeTransferFrom(msg.sender, s.luckyWheelTreasury, amount);

        emit LuckyWheelBought(token, msg.sender, s.luckyWheelTreasury, amount, orderId);
    }

    /**
     * @notice Buy a specific lucky wheel via callers
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
    function callBuyLuckyWheel(
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
        LuckyWheelStorage storage s = getStorage();
        IERC20(token).safeTransferFrom(from, s.luckyWheelTreasury, amount);
        
        uint256 gasPrice = getUserOpGasPrice(maxFeePerGas, maxPriorityFeePerGas);
        uint256 actualGas = preGas - gasleft() + s.bufferPostOp;
        uint256 actualGasCost = actualGas * gasPrice;
        uint256 actualPaymentCost = actualGasCost * paymentPrice / DENOMINATOR;
        
        IERC20(s.paymentToken).safeTransferFrom(from, s.luckyWheelTreasury, actualPaymentCost);
        emit CallBuyLuckyWheel(
            msg.sender,
            token,
            from,
            to,
            amount,
            actualPaymentCost,
            orderId
        );
        return (actualGasCost, actualPaymentCost);
    }

    /// @notice Get storage position of lucky wheel configuration
    function getStorage() internal pure returns (LuckyWheelStorage storage dc) {
        bytes32 position = LUCKY_WHEEL_CONFIG_STORAGE_POSITION;
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
