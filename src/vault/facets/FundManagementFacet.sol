// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibAsset } from "../libraries/LibAsset.sol";

contract FundManagementFacet {
    /// Events
    event DepositAsset(
        address indexed depositer,
        address indexed assetAddress,
        uint256 amount
    );
    event WithdrawAsset(
        address indexed caller,
        address indexed assetAddress,
        address indexed to,
        uint256 amount    
    );

    /**
     * @notice Deposit an asset.
     * @param assetAddress asset address.
     * @param amount withdrawn amount
     */
    function depositAsset(
        address assetAddress,
        uint256 amount
    ) external payable {
        LibAsset.depositAsset(assetAddress, amount);
        emit DepositAsset(msg.sender, assetAddress, amount);
    }

    /**
     * @notice Withdraw an asset.
     * @param assetAddress asset address.
     * @param to beneficiary address.
     * @param amount withdrawn amount
     */
    function withdrawAsset(
        address assetAddress,
        address to,
        uint256 amount
    ) external {
        LibDiamond.enforceIsContractOwner();
        LibAsset.transferAsset(assetAddress, payable(to), amount);
        emit WithdrawAsset(msg.sender, assetAddress, to, amount);
    }
}
