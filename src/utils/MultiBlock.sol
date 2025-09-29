// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BicTokenPaymaster} from "../BicTokenPaymaster.sol";

contract BicMultiBlock is Ownable {
    BicTokenPaymaster bic;

    event TransferBicOwner(address executor, address newBicOwner);
    event MultiBlock(address[] addresses);
    event MultiUnblock(address[] addresses);
    constructor(address _owner, address _bic) Ownable(_owner) {
        bic = BicTokenPaymaster(payable(_bic));
    }

    function transferBicOwner(address newOwner) external onlyOwner {
        bic.transferOwnership(newOwner);
        emit TransferBicOwner(_msgSender(), newOwner);
    }

    function multiBlock(address[] memory addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            address blockAddress = addresses[i];
            bic.blockAddress(blockAddress, true);
        }
        emit MultiBlock(addresses);
    }

    function multiUnblock(address[] memory addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            address blockAddress = addresses[i];
            bic.blockAddress(blockAddress, false);
        }
        emit MultiUnblock(addresses);
    }
}