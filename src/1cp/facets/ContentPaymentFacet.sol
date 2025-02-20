// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import { LibAccess } from "../libraries/LibAccess.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ContentPaymentFacet {
    using SafeERC20 for IERC20;
    // Struct
    struct ContentPaymentStruct {
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
        string customerId,
        string contentId
    );
    event CallBuyContent(
        address caller,
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 surcharge,
        uint256 fee,
        string customerId,
        string contentId
    );

    function getStorage() internal pure returns (ContentPaymentStruct storage dc) {
        bytes32 position = CONTENT_CONFIG_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            dc.slot := position
        }
    }

    function updateContentTreasury(address newTreasury) external {
        LibDiamond.enforceIsContractOwner();
        if (newTreasury == address(0)) {
            revert ZeroAddress();
        }
        ContentPaymentStruct storage s = getStorage();
        s.contentTreasury = newTreasury;
        emit ContentTreasuryUpdated(msg.sender, newTreasury);
    }

    function updatePaymentToken(address paymentToken) external {
        LibDiamond.enforceIsContractOwner();
        if (paymentToken == address(0)) {
            revert ZeroAddress();
        }
        ContentPaymentStruct storage s = getStorage();
        s.paymentToken = paymentToken;
        emit PaymentTokenUpdated(msg.sender, paymentToken);
    }

    function updateSurchargeFee(uint256 surchargeFee) external {
        LibDiamond.enforceIsContractOwner();
        if (surchargeFee > 10_000) {
            revert InvalidSurchargeFee(surchargeFee);
        }
        ContentPaymentStruct storage s = getStorage();
        s.surchargeFee = surchargeFee;
        emit SurchargeFeeUpdated(msg.sender, surchargeFee);
    }

    function updateBufferPostOp(uint256 bufferPostOp) external {
        LibDiamond.enforceIsContractOwner();
        ContentPaymentStruct storage s = getStorage();
        s.bufferPostOp = bufferPostOp;
        emit BufferPostOpUpdated(msg.sender, bufferPostOp);
    }

    function buyContent(
        address token,
        address to,
        uint256 amount,
        string memory customerId,
        string memory contentId
    ) external {
        if (amount == 0) {
            revert ZeroPayment();
        }
        ContentPaymentStruct memory s = getStorage();
        uint256 surcharge = amount * s.surchargeFee / 10_000;
        IERC20(token).safeTransferFrom(msg.sender, to, amount - surcharge);
        IERC20(token).safeTransferFrom(msg.sender, s.contentTreasury, surcharge);
        emit ContentBought(token, msg.sender, to, amount, surcharge, customerId, contentId);
    }

    function callBuyContent(
        uint256 amount,
        uint256 maxFeePerGas,
        uint256 maxPriorityFeePerGas,
        uint256 paymentPrice,
        address token,
        address from,
        address to,
        string memory customerId,
        string memory contentId
    ) external returns (uint256, uint256) {
        uint256 preGas = gasleft();
        LibAccess.enforceAccessControl();
        if (amount == 0) {
            revert ZeroPayment();
        }
        ContentPaymentStruct memory s = getStorage();
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
            customerId,
            contentId
        );
        return (actualGasCost, actualPaymentCost);
    }

    /**
     * the gas price this UserOp agrees to pay.
     * relayer/block builder might submit the TX with higher priorityFee, but the user should not
     */
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
