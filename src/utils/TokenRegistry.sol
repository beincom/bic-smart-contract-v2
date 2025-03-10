// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;


import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenRegistry is Ownable {
    mapping(address => bool) public tokens;

    event TokenERC20Added(address indexed token, uint256 blockAt);
    event TokenERC721Added(address indexed token, uint256 blockAt);

    function registerERC20(address token, uint256 blockAt) external onlyOwner {
        require(!tokens[token], "TokenRegistry: token already registered");
        tokens[token] = true;
        emit TokenERC20Added(token, blockAt);
    }

    function registerERC721(address token, uint256 blockAt) external onlyOwner {
        require(!tokens[token], "TokenRegistry: token already registered");
        tokens[token] = true;
        emit TokenERC721Added(token, blockAt);
    }
}