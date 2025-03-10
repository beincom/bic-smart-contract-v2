// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Erc20TransferMessage is Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_BPS = 10_000;
    
    /// @dev  Treasury address
    address public treasury;
    /// @dev  Percentage fee
    uint256 public feeBps;

    /// Errors
    error ZeroAmount();
    error ZeroAddress();
    error InvalidBPS();
    /// Events
    event ERC20Message(
        IERC20 indexed token,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 amountFee,
        uint256 amountRemaining,
        string message
    );
    event WithdrawToken(
        IERC20 indexed token,
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event SetTreasury(address oldTreasury, address newTreasury);
    event SetFeeBps(uint256 oldFeeBps, uint256 newFeeBps);

    constructor(address _treasury, address _owner) Ownable(_owner) {
        treasury = _treasury;
        feeBps = 600;
    }

    /**
     * @notice Transfer ERC20 with a specific message
     * @param _token The token transferred address
     * @param _to The beneficiary address
     * @param _amount The transferred amount
     * @param _message The message triggered to transfer
     */
    function transferERC20(
        IERC20 _token,
        address _to,
        uint256 _amount,
        string calldata _message
    ) external {
        if (_amount == 0) {
            revert ZeroAmount();
        }

        uint256 amountFee;
        if(treasury != address(0) && feeBps > 0) { 
            amountFee = (_amount * feeBps) / MAX_BPS;
            _token.safeTransferFrom(_msgSender(), treasury, amountFee);
        }

        uint256 amountRemaining = _amount - amountFee;
        _token.safeTransferFrom(_msgSender(), _to, amountRemaining);
        emit ERC20Message(_token, _msgSender(), _to, _amount, amountFee, amountRemaining, _message);
    }

    /// @notice Update treasury address
    /// @param _newTreasury The new treasury address
    function setTreasury(address _newTreasury) external onlyOwner {
        if (_newTreasury == address(0)) {
            revert ZeroAddress();
        }
        address oldTreasury = treasury;
        treasury = _newTreasury;
        emit SetTreasury(oldTreasury, _newTreasury);
    }

    /// @notice Update surcharge fee
    /// @param _newFeeBps The new surcharge fee
    function setFeeBps(uint256 _newFeeBps) external onlyOwner {
        if (_newFeeBps > 10_000) {
            revert InvalidBPS();
        }
        uint256 oldFeeBps = feeBps;
        feeBps = _newFeeBps;
        emit SetFeeBps(oldFeeBps, _newFeeBps);
    }
}
