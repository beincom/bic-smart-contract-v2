// Solidity Version: 0.8.23
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestBIC is ERC20 {
    constructor() ERC20("TestBIC", "BIC") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    // Very basic mint function.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}