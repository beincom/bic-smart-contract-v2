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

    event ERC20Message(
        IERC20 indexed token,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 amountFee,
        uint256 amountRemaining,
        string message
    );

     event ERC20Charge(
        IERC20 indexed token,
        address indexed from,
        address indexed to,
        uint256 amount,
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

    constructor() {}

    function transferERC20(
        IERC20 _token,
        address _to,
        uint256 _amount,
        string calldata _message
    ) external {
        require(_amount > 0, "TM: Amount must be greater than zero");

        uint256 amountFee;
        if(treasury != address(0) && feeBps > 0) { 
            amountFee = (_amount * feeBps) / MAX_BPS;
            _token.safeTransferFrom(_msgSender(), treasury, amountFee);
        }

        uint256 amountRemaining = _amount - amountFee;
        _token.safeTransferFrom(_msgSender(), _to, amountRemaining);
        emit ERC20Message(_token, _msgSender(), _to, _amount, amountFee, amountRemaining, _message);
    }

    function transferERC20(
        IERC20 _token,
        address _to,
        uint256 _amount,
        string calldata _message
    ) external {
        require(_amount > 0, "TM: Amount must be greater than zero");

        uint256 amountFee;
        if(treasury != address(0) && feeBps > 0) { 
            amountFee = (_amount * feeBps) / MAX_BPS;
            _token.safeTransferFrom(_msgSender(), treasury, amountFee);
        }

        uint256 amountRemaining = _amount - amountFee;
        _token.safeTransferFrom(_msgSender(), _to, amountRemaining);
        emit ERC20Message(_token, _msgSender(), _to, _amount, amountFee, amountRemaining, _message);
    }


    function setTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury!= address(0), "TM: Zero address");
        address oldTreasury = treasury;
        treasury = _newTreasury;
        emit SetTreasury(oldTreasury, _newTreasury);
    }

    function setFeeBps(uint256 _newFeeBps) external onlyOwner {
        require(_newFeeBps<= 10000, "TM: Exceeds max bps");
        uint256 oldFeeBps = feeBps;
        feeBps = _newFeeBps;
        emit SetFeeBps(oldFeeBps, _newFeeBps);
    }

}
