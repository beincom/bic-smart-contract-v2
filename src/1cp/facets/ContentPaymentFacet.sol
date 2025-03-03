// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import { LibAccess } from "../libraries/LibAccess.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ContentPaymentFacet {
    using SafeERC20 for IERC20;
    // Struct
    struct ContentPaymentStorage {
        uint256 surchargeFee;
        uint256 bufferPostOp;
        address contentTreasury;
        address paymentToken;
    }

    /// Errors
    error ZeroPayment();
    error ZeroAddress();
    error InvalidSurchargeFee(uint256 surchargeFee);

    /// Storage
    bytes32 internal constant CONTENT_CONFIG_STORAGE_POSITION = keccak256("1CP.content.config.storage");

    /// Events
    event ContentTreasuryUpdated(address updater, address newTreasury);
    event PaymentTokenUpdated(address updater, address newPaymentToken);
    event SurchargeFeeUpdated(address updater, uint256 surchargeFee);
    event BufferPostOpUpdated(address updater, uint256 bufferPostOp);
    event ContentBought(
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 surcharge,
        string orderId
    );
    event CallBuyContent(
        address caller,
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 surcharge,
        uint256 fee,
        string orderId
    );

    /// @notice Get content config storage
    function getContentPaymentStorage() external pure returns (
        uint256 surchargeFee,
        uint256 bufferPostOp,
        address contentTreasury,
        address paymentToken
    ) {
        ContentPaymentStorage memory s = getStorage();
        return (s.surchargeFee, s.bufferPostOp, s.contentTreasury, s.paymentToken);
    }

    /// @notice Update donation treasury address
    /// @param newTreasury The new donation treasury address
    function updateContentTreasury(address newTreasury) external {
        LibDiamond.enforceIsContractOwner();
        if (newTreasury == address(0)) {
            revert ZeroAddress();
        }
        ContentPaymentStorage storage s = getStorage();
        s.contentTreasury = newTreasury;
        emit ContentTreasuryUpdated(msg.sender, newTreasury);
    }

    /// @notice Update donation payment token address
    /// @param paymentToken The payment token address used for reimbursing gas fee via callBuyContent
    function updateContentPaymentToken(address paymentToken) external {
        LibDiamond.enforceIsContractOwner();
        if (paymentToken == address(0)) {
            revert ZeroAddress();
        }
        ContentPaymentStorage storage s = getStorage();
        s.paymentToken = paymentToken;
        emit PaymentTokenUpdated(msg.sender, paymentToken);
    }

    /// @notice Update surcharge fee
    /// @param surchargeFee The surcharge fee used for deducting upfront fee of the specific services
    function updateContentSurchargeFee(uint256 surchargeFee) external {
        LibDiamond.enforceIsContractOwner();
        if (surchargeFee > 10_000) {
            revert InvalidSurchargeFee(surchargeFee);
        }
        ContentPaymentStorage storage s = getStorage();
        s.surchargeFee = surchargeFee;
        emit SurchargeFeeUpdated(msg.sender, surchargeFee);
    }

    /// @notice Update buffer gas for post ops
    /// @param bufferPostOp The additional gas used for additional execution via callBuyContent
    function updateContentBufferPostOp(uint256 bufferPostOp) external {
        LibDiamond.enforceIsContractOwner();
        ContentPaymentStorage storage s = getStorage();
        s.bufferPostOp = bufferPostOp;
        emit BufferPostOpUpdated(msg.sender, bufferPostOp);
    }

    /**
     * @notice Buy a specific content
     * @param token The payment token
     * @param to The seller adderss
     * @param amount The selling amount
     * @param orderId The off-chain orderId based on services
     */
    function buyContent(
        address token,
        address to,
        uint256 amount,
        string memory orderId
    ) external {
        if (amount == 0) {
            revert ZeroPayment();
        }
        ContentPaymentStorage storage s = getStorage();
        uint256 surcharge = amount * s.surchargeFee / 10_000;
        IERC20(token).safeTransferFrom(msg.sender, to, amount - surcharge);
        IERC20(token).safeTransferFrom(msg.sender, s.contentTreasury, surcharge);
        emit ContentBought(token, msg.sender, to, amount, surcharge, orderId);
    }

    /**
     * @notice Buy a specific content via callers
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
    function callBuyContent(
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
        ContentPaymentStorage storage s = getStorage();
        uint256 gasPrice = getUserOpGasPrice(maxFeePerGas, maxPriorityFeePerGas);
        uint256 actualGas = preGas - gasleft() + s.bufferPostOp;
        uint256 actualGasCost = actualGas * gasPrice;
        uint256 actualPaymentCost = actualGasCost * paymentPrice;
        uint256 surcharge = amount * s.surchargeFee / 10_000;
        IERC20(token).safeTransferFrom(from, to, amount - surcharge);
        IERC20(token).safeTransferFrom(from, s.contentTreasury, surcharge);
        IERC20(s.paymentToken).safeTransferFrom(from, s.contentTreasury, actualPaymentCost);
        emit CallBuyContent(
            msg.sender,
            token,
            from,
            to,
            amount,
            surcharge,
            actualPaymentCost,
            orderId
        );
        return (actualGasCost, actualPaymentCost);
    }

    /// @notice Get storage position of content configuration
    function getStorage() internal pure returns (ContentPaymentStorage storage dc) {
        bytes32 position = CONTENT_CONFIG_STORAGE_POSITION;
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
