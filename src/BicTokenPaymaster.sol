// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "./base/BasePaymasterUpgradeable.sol";
import "./base/MultiSigner.sol";
import "./base/TokenSingletonPaymaster.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/IPaymaster.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title A paymaster that defines itself also BIC main token
 * @notice Using this paymaster mechanism for Account Abstraction bundler v0.6,
 * when need to change to bundler v0.7 or higher, using TokenPaymaster instead
 */
contract BicTokenPaymaster is TokenSingletonPaymaster, PausableUpgradeable, UUPSUpgradeable {
    bytes32 public constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev Emitted when a user is blocked
    event BlockPlaced(address indexed _user, address indexed _operator);

    /// @dev Emitted when a user is unblocked
    event BlockReleased(address indexed _user, address indexed _operator);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _entryPoint, address _owner, address[] memory _singers) public initializer {
        __TokenSingletonPaymaster_init(_entryPoint, _singers);
        __ERC20_init("Beincom", "BIC");
        __ERC20Votes_init();
        __Pausable_init();
        _mint(_owner, 5000000000 * 1e18);
        _approve(address(this), _owner, type(uint).max);
        transferOwnership(_owner);
    }

    /**
     * @notice Blacklist a user.
     * @param _user the user to blacklist.
     */
    function addToBlockedList (address _user) public onlyOwner {
        isBlocked[_user] = true;
        emit BlockPlaced(_user, msg.sender);
    }

    /**
     * @notice Unblock a user.
     * @param _user the user to unblock.
     */
    function removeFromBlockedList (address _user) public onlyOwner {
        isBlocked[_user] = false;
        emit BlockReleased(_user, msg.sender);
    }

    /**
     * @notice Pause transfers using this token. For emergency use.
     * @dev Event already defined and emitted in Pausable.sol
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause transfers using this token.
     * @dev Event already defined and emitted in Pausable.sol
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Hook that is called before any transfer of tokens.
     * Override existing hook to add additional checks: paused and blocked users.
     */
    function _update(address from, address to, uint256 amount) internal virtual override {
        super._update(from, to, amount);

        require(!paused(), "BicTokenPaymaster: token transfer while paused");
        require(!isBlocked[from], "BicTokenPaymaster: sender is blocked");
    }

    /// @notice Returns the implementation of the ERC1967 proxy.
    ///
    /// @return $ The address of implementation contract.
    function implementation() public view returns (address $) {
        assembly {
            $ := sload(IMPLEMENTATION_SLOT)
        }
    }

    /// @inheritdoc UUPSUpgradeable
    ///
    /// @dev Authorization logic is only based on the `msg.sender` being an owner of this account,
    ///      or `address(this)`.
    function _authorizeUpgrade(address) internal view virtual override(UUPSUpgradeable) onlyOwner {}
}
