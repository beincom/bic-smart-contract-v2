// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import { LibAccess } from "../libraries/LibAccess.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";
import { Initializable } from "../utils/Initializable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DonationFacet is Initializable {
    using SafeERC20 for IERC20;
    /// Struct
    struct DonationConfigStorage {
        uint256 surchargeFee;
        uint256 bufferPostOp;
        address donationTreasury;
        address paymentToken;
    }

    /// Errors
    error ZeroDonation();
    error ZeroAddress();
    error InvalidSurchargeFee(uint256 surchargeFee);

    /// Storage
    uint256 internal constant DENOMINATOR = 1e10;
    bytes32 internal constant DONATION_CONFIG_STORAGE_POSITION = keccak256("1CP.donation.config.storage");

    /// Events
    event InitializedDonationConfig(
        address treasury,
        address paymentToken,
        uint256 surchargeFee,
        uint256 bufferPostOp
    );
    event DonationTreasuryUpdated(address updater, address newTreasury);
    event PaymentTokenUpdated(address updater, address newPaymentToken);
    event SurchargeFeeUpdated(address updater, uint256 surchargeFee);
    event BufferPostOpUpdated(address updater, uint256 bufferPostOp);
    event Donated(
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 surcharge,
        string message
    );
    event CallDonation(
        address caller,
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 surcharge,
        uint256 fee,
        string message
    );

    /// @notice Get donation config storage
    function getDonationConfigStorage() external pure returns (
        uint256 surchargeFee,
        uint256 bufferPostOp,
        address contentTreasury,
        address paymentToken
    ) {
        DonationConfigStorage memory s = getStorage();
        return (s.surchargeFee, s.bufferPostOp, s.donationTreasury, s.paymentToken);
    }

    /**
     * @notice Initialize donation config
     * @param treasury the donation treasury address
     * @param paymentToken The payment token address used for reimbursing gas fee via callDonation
     * @param surchargeFee The surcharge fee used for deducting upfront fee of the specific services
     * @param bufferPostOp The additional gas used for additional execution via callDonation
     */
    function initializeDonationConfig(
        address treasury,
        address paymentToken,
        uint256 surchargeFee,
        uint256 bufferPostOp
    ) external initializer {
        LibDiamond.enforceIsContractOwner();
        if (treasury == address(0) || paymentToken == address(0)) {
            revert ZeroAddress();
        }
        if (surchargeFee > 10_000) {
            revert InvalidSurchargeFee(surchargeFee);
        }
        DonationConfigStorage storage s = getStorage();
        s.donationTreasury = treasury;
        s.paymentToken = paymentToken;
        s.surchargeFee = surchargeFee;
        s.bufferPostOp = bufferPostOp;
        emit InitializedDonationConfig(treasury, paymentToken, surchargeFee, bufferPostOp);
    }

    /// @notice Update donation treasury address
    /// @param newTreasury The new donation treasury address
    function updateDonationTreasury(address newTreasury) external {
        LibDiamond.enforceIsContractOwner();
        if (newTreasury == address(0)) {
            revert ZeroAddress();
        }
        DonationConfigStorage storage s = getStorage();
        s.donationTreasury = newTreasury;
        emit DonationTreasuryUpdated(msg.sender, newTreasury);
    }

    /// @notice Update donation payment token address
    /// @param paymentToken The payment token address used for reimbursing gas fee via callDonation
    function updateDonationPaymentToken(address paymentToken) external {
        LibDiamond.enforceIsContractOwner();
        if (paymentToken == address(0)) {
            revert ZeroAddress();
        }
        DonationConfigStorage storage s = getStorage();
        s.paymentToken = paymentToken;
        emit PaymentTokenUpdated(msg.sender, paymentToken);
    }

    /// @notice Update surcharge fee
    /// @param surchargeFee The surcharge fee used for deducting upfront fee of the specific services
    function updateDonationSurchargeFee(uint256 surchargeFee) external {
        LibDiamond.enforceIsContractOwner();
        if (surchargeFee > 10_000) {
            revert InvalidSurchargeFee(surchargeFee);
        }
        DonationConfigStorage storage s = getStorage();
        s.surchargeFee = surchargeFee;
        emit SurchargeFeeUpdated(msg.sender, surchargeFee);
    }

    /// @notice Update buffer gas for post ops
    /// @param bufferPostOp The additional gas used for additional execution via callDonation
    function updateDonationBufferPostOp(uint256 bufferPostOp) external {
        LibDiamond.enforceIsContractOwner();
        DonationConfigStorage storage s = getStorage();
        s.bufferPostOp = bufferPostOp;
        emit BufferPostOpUpdated(msg.sender, bufferPostOp);
    }

    /**
     * @notice Donate a specific token
     * @param token The token donated
     * @param to The beneficiary address received donation
     * @param amount The donated amount
     * @param message The message triggered to donation
     */
    function donate(
        address token,
        address to,
        uint256 amount,
        string calldata message
    ) external {
        if (amount == 0) {
            revert ZeroDonation();
        }
        DonationConfigStorage storage s = getStorage();
        uint256 surcharge = amount * s.surchargeFee / 10_000;
        IERC20(token).safeTransferFrom(msg.sender, to, amount - surcharge);
        
        if (surcharge > 0) {
            IERC20(token).safeTransferFrom(msg.sender, s.donationTreasury, surcharge);
        }

        emit Donated(token, msg.sender, to, amount, surcharge, message);
    }

    /**
     * @notice Donate a specific token via callers
     * @param token The token donated
     * @param from The donator address
     * @param to The beneficiary address received donation
     * @param amount The donated amount
     * @param message The message triggered to donation
     * @param maxFeePerGas The maximum fee per a gas unit
     * @param maxPriorityFeePerGas The maximum priority fee per a gas unit
     * @param paymentPrice The exchanged ratio of payment token and native gas token
     * @return The actual gas cost
     * @return The actual payment cost
     */
    function callDonation(
        address token,
        address from,
        address to,
        uint256 amount,
        string memory message,
        uint256 maxFeePerGas,
        uint256 maxPriorityFeePerGas,
        uint256 paymentPrice
    ) external returns (uint256, uint256) {
        uint256 preGas = gasleft();
        LibAccess.enforceAccessControl();
        if (amount == 0) {
            revert ZeroDonation();
        }
        DonationConfigStorage storage s = getStorage();
        uint256 surcharge = amount * s.surchargeFee / 10_000;
        IERC20(token).safeTransferFrom(from, to, amount - surcharge);
        
        if (surcharge > 0) {
            IERC20(token).safeTransferFrom(from, s.donationTreasury, surcharge);
        }
        
        uint256 gasPrice = getUserOpGasPrice(maxFeePerGas, maxPriorityFeePerGas);
        uint256 actualGas = preGas - gasleft() + s.bufferPostOp;
        uint256 actualGasCost = actualGas * gasPrice;
        uint256 actualPaymentCost = actualGasCost * paymentPrice / DENOMINATOR;
        
        IERC20(s.paymentToken).safeTransferFrom(from, s.donationTreasury, actualPaymentCost);
        
        emit CallDonation(
            msg.sender,
            token,
            from,
            to,
            amount,
            surcharge,
            actualPaymentCost,
            message
        );
        return (actualGasCost, actualPaymentCost);
    }
    
    /// @notice Get storage position of donation configuration
    function getStorage() internal pure returns (DonationConfigStorage storage dc) {
        bytes32 position = DONATION_CONFIG_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            dc.slot := position
        }
    }

    /// the gas price this UserOp agrees to pay.
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
