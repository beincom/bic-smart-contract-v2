// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BicTokenPaymaster} from "../BicTokenPaymaster.sol";

contract BicMultiBlock is Ownable {
    address public bic;

    event UpdateBic(address newBic);
    event TransferBicOwner(address executor, address newBicOwner);
    event MultiBlock(address[] addresses);
    event MultiUnblock(address[] addresses);
    constructor(address _owner, address _bic) Ownable(_owner) {
        bic = _bic;
    }

    function updateBic(address newBic) external onlyOwner {
        bic = newBic;
        emit UpdateBic(newBic);
    }

    function transferBicOwner(address newOwner) external onlyOwner {
        BicTokenPaymaster(payable(bic)).transferOwnership(newOwner);
        emit TransferBicOwner(_msgSender(), newOwner);
    }

    function multiBlock(address[] memory addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            address blockAddress = addresses[i];
            BicTokenPaymaster(payable(bic)).blockAddress(blockAddress, true);
        }
        emit MultiBlock(addresses);
    }

    function multiUnblock(address[] memory addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            address blockAddress = addresses[i];
            BicTokenPaymaster(payable(bic)).blockAddress(blockAddress, false);
        }
        emit MultiUnblock(addresses);
    }
}