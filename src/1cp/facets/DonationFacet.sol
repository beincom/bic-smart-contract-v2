// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import { LibAccess } from "../libraries/LibAccess.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DonationFacet {
    using SafeERC20 for IERC20;

    /// Errors
    error ZeroDonation();

    /// Storage
    bytes32 internal constant DONATION_CONFIG_STORAGE_POSITION = keccak256("1CP.donation.config.storage");

    struct DonationConfigStruct {
        address donationTreasury;
        uint256 surcharge;
    }

    event Donated(
        address token,
        address from,
        address to,
        uint256 amount,
        string message
    );

    function donationConfigStorage() internal pure returns (DonationConfigStruct storage dc) {
        bytes32 position = DONATION_CONFIG_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            dc.slot := position
        }
    }

    function donate(
        address token,
        address to,
        uint256 amount,
        string calldata message
    ) external {
        if (amount == 0) {
            revert ZeroDonation();
        }
        IERC20(token).safeTransferFrom(msg.sender, to, amount);
        emit Donated(token, msg.sender, to, amount, message);
    }

    function callDonation(
        address token,
        address from,
        address to,
        uint256 amount,
        string calldata message
    ) external {
        LibAccess.enforceAccessControl();
        if (amount == 0) {
            revert ZeroDonation();
        }
        IERC20(token).safeTransferFrom(from, to, amount);
        emit Donated(token, from, to, amount, message);
    }
}
