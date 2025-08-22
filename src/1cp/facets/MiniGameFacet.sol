// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import { LibAccess } from "../../diamond/libraries/LibAccess.sol";
import { LibDiamond } from "../../diamond/libraries/LibDiamond.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MiniGameFacet {
    using SafeERC20 for IERC20;
    // Struct
    struct MiniGameStorage {
        uint8 initialMiniGameConfig;
        uint256 bufferPostOp;
        uint256 rewardPercent; // unit in basic points (100% = 10000)
        address miniGameTreasury;
        address rewardPool;
        address paymentToken;
    }

    /// Errors
    error ZeroPayment();
    error ZeroAddress();
    error InvalidRewardPercent();
    error AlreadyInitialized();

    /// Storage
    uint256 internal constant DENOMINATOR = 1e10;
    bytes32 internal constant MINI_GAME_CONFIG_STORAGE_POSITION = keccak256("1CP.mini.game.config.storage");

    /// Events
    event InitializedMiniGameConfig(
        uint256 bufferPostOp,
        uint256 rewardPercent,
        address treasury,
        address rewardPool,
        address paymentToken
    );
    event MiniGameTreasuryUpdated(address updater, address newTreasury);
    event PaymentTokenUpdated(address updater, address newPaymentToken);
    event BufferPostOpUpdated(address updater, uint256 bufferPostOp);
    event RewardConfigUpdated(address updater, address rewardPool, uint256 rewardPercent);
    event ToolPackBought(
        address token,
        address from,
        address to,
        uint256 amount,
        string orderId
    );
    event CallBuyToolPack(
        address caller,
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 fee,
        string orderId,
        uint256 paymentPrice
    );

    modifier initializer() {
        MiniGameStorage storage s = getStorage();
        if (s.initialMiniGameConfig != 0) {
            revert AlreadyInitialized();
        }
        s.initialMiniGameConfig = 1;
        _;
    }

    /// @notice Get mini game storage
    function getMiniGameStorage() external pure returns (
        uint256 bufferPostOp,
        uint256 rewardPercent,
        address miniGameTreasury,
        address rewardPool,
        address paymentToken
    ) {
        MiniGameStorage memory s = getStorage();
        return (
            s.bufferPostOp,
            s.rewardPercent,
            s.miniGameTreasury,
            s.rewardPool,
            s.paymentToken
        );
    }

    /**
     * @notice Initialize mini game config
     * @param bufferPostOp The additional gas used for additional execution via callBuyToolPack
     * @param rewardPercent The percentage for reward pool
     * @param treasury the mini game treasury address
     * @param rewardPool the mini game reward pool address
     * @param paymentToken The payment token address used for reimbursing gas fee via callBuyToolPack
     */
    function initializeMiniGameConfig(
        uint256 bufferPostOp,
        uint256 rewardPercent,
        address treasury,
        address rewardPool,
        address paymentToken
    ) external initializer {
        LibDiamond.enforceIsContractOwner();
        if (
            treasury == address(0) ||
            paymentToken == address(0) ||
            rewardPool == address(0)
        ) {
            revert ZeroAddress();
        }

        if (rewardPercent > 10000) {
            revert InvalidRewardPercent();
        }

        MiniGameStorage storage s = getStorage();
        s.bufferPostOp = bufferPostOp;
        s.rewardPercent = rewardPercent;
        s.miniGameTreasury = treasury;
        s.rewardPool = rewardPool;
        s.paymentToken = paymentToken;

        emit InitializedMiniGameConfig(
            bufferPostOp,
            rewardPercent,
            treasury,
            rewardPool,
            paymentToken
        );
    }

    /// @notice Update mini game treasury address
    /// @param newTreasury The new mini game treasury address
    function updateMiniGameTreasury(address newTreasury) external {
        LibDiamond.enforceIsContractOwner();
        if (newTreasury == address(0)) {
            revert ZeroAddress();
        }
        MiniGameStorage storage s = getStorage();
        s.miniGameTreasury = newTreasury;
        emit MiniGameTreasuryUpdated(msg.sender, newTreasury);
    }

    /// @notice Update mini game payment token address
    /// @param paymentToken The payment token address used for reimbursing gas fee via callBuyToolPack
    function updateMiniGamePaymentToken(address paymentToken) external {
        LibDiamond.enforceIsContractOwner();
        if (paymentToken == address(0)) {
            revert ZeroAddress();
        }
        MiniGameStorage storage s = getStorage();
        s.paymentToken = paymentToken;
        emit PaymentTokenUpdated(msg.sender, paymentToken);
    }

    /// @notice Update buffer gas for post ops
    /// @param bufferPostOp The additional gas used for additional execution via callBuyToolPack
    function updateMiniGameBufferPostOp(uint256 bufferPostOp) external {
        LibDiamond.enforceIsContractOwner();
        MiniGameStorage storage s = getStorage();
        s.bufferPostOp = bufferPostOp;
        emit BufferPostOpUpdated(msg.sender, bufferPostOp);
    }

    /**
     * @notice Update reward config
     * @param rewardPool The reward pool address
     * @param rewardPercent The percentage for reward pool
     */
    function updateRewardConfig(address rewardPool, uint256 rewardPercent) external {
        LibDiamond.enforceIsContractOwner();

        if (rewardPercent > 10000) {
            revert InvalidRewardPercent();
        }
        
        MiniGameStorage storage s = getStorage();
        s.rewardPool = rewardPool;
        s.rewardPercent = rewardPercent;
        emit RewardConfigUpdated(msg.sender, rewardPool, rewardPercent);
    }

    /**
     * @notice Buy a specific mini game tool pack
     * @param token The payment token
     * @param to The seller adderss
     * @param amount The selling amount
     * @param orderId The off-chain orderId based on services
     */
    function buyToolPack(
        address token,
        address to,
        uint256 amount,
        string memory orderId
    ) external {
        if (amount == 0) {
            revert ZeroPayment();
        }
        MiniGameStorage storage s = getStorage();
        uint256 rewardAmount = amount * s.rewardPercent / 10000;
        IERC20(token).safeTransferFrom(msg.sender, s.rewardPool, rewardAmount);
        IERC20(token).safeTransferFrom(msg.sender, s.miniGameTreasury, amount - rewardAmount);

        emit ToolPackBought(token, msg.sender, s.miniGameTreasury, amount, orderId);
    }

    /**
     * @notice Buy a specific mini game tool pack via callers
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
    function callBuyToolPack(
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
        MiniGameStorage storage s = getStorage();
        uint256 rewardAmount = amount * s.rewardPercent / 10000;
        IERC20(token).safeTransferFrom(from, s.rewardPool, rewardAmount);
        IERC20(token).safeTransferFrom(from, s.miniGameTreasury, amount - rewardAmount);
        
        uint256 gasPrice = getUserOpGasPrice(maxFeePerGas, maxPriorityFeePerGas);
        uint256 actualGas = preGas - gasleft() + s.bufferPostOp;
        uint256 actualGasCost = actualGas * gasPrice;
        uint256 actualPaymentCost = actualGasCost * paymentPrice / DENOMINATOR;
        
        IERC20(s.paymentToken).safeTransferFrom(from, s.miniGameTreasury, actualPaymentCost);
        emit CallBuyToolPack(
            msg.sender,
            token,
            from,
            to,
            amount,
            actualPaymentCost,
            orderId,
            paymentPrice
        );
        return (actualGasCost, actualPaymentCost);
    }

    /// @notice Get storage position of mini game configuration
    function getStorage() internal pure returns (MiniGameStorage storage dc) {
        bytes32 position = MINI_GAME_CONFIG_STORAGE_POSITION;
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
