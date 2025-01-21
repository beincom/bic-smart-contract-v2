// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Treasury is Ownable {
    /// @notice Emitted when the treasury is updated.
    event UpdateTreasury(address indexed updater,address newTreasury);

    address public treasury;

    constructor(address _treasury) {
        treasury = _treasury;
    }

    function updateTreasury(address _newTreasury) public onlyOwner {
        treasury = _newTreasury;
        emit UpdateTreasury(_msgSender(), _newTreasury);
    }
}