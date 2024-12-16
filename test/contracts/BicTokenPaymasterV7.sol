// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "../../src/base/BasePaymasterUpgradeable.sol";
import "../../src/base/MultiSigner.sol";
import "../../src/base/TokenSingletonPaymaster.sol";
import "../lib/BicTokenPaymasterStorageV2.sol";

import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/IPaymaster.sol";
import "@account-abstraction-v7/contracts/interfaces/PackedUserOperation.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {console} from "forge-std/console.sol";

contract BicTokenPaymasterV7 is
    TokenSingletonPaymaster,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using BicTokenPaymasterStorage for BicTokenPaymasterStorage.Data;

    /// @dev Emitted when a user is blocked
    event BlockPlaced(address indexed _user, address indexed _operator);

    /// @dev Emitted when a user is unblocked
    event BlockReleased(address indexed _user, address indexed _operator);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _entryPoint,
        address _owner,
        address[] memory _singers
    ) public initializer {
        __TokenSingletonPaymaster_init(_entryPoint, _singers);
        __ERC20_init("Beincom", "BIC");
        __ERC20Votes_init();
        __Pausable_init();
        _mint(_owner, 5000000000 * 1e18);
        _approve(address(this), _owner, type(uint).max);
        transferOwnership(_owner);
    }

    /**
     * @notice Check if a user is blocked.
     * @param _user the user to check.
     */
    function isBlocked(address _user) public view returns (bool) {
        BicTokenPaymasterStorage.Data storage $ = BicTokenPaymasterStorage
            ._getStorageLocation();
        return $._isBlocked[_user];
    }

    /**
     * @notice Blacklist a user.
     * @param _user the user to blacklist.
     */
    function addToBlockedList(address _user) public onlyOwner {
        BicTokenPaymasterStorage.Data storage $ = BicTokenPaymasterStorage
            ._getStorageLocation();
        $._isBlocked[_user] = true;
        emit BlockPlaced(_user, msg.sender);
    }

    /**
     * @notice Unblock a user.
     * @param _user the user to unblock.
     */
    function removeFromBlockedList(address _user) public onlyOwner {
        BicTokenPaymasterStorage.Data storage $ = BicTokenPaymasterStorage
            ._getStorageLocation();
        $._isBlocked[_user] = false;
        emit BlockReleased(_user, msg.sender);
    }

    /**
     * @notice Pause transfers using this token. For emergency use.
     * @dev Event already defined and emitted in Pausable.sol
     */
    function pause() public onlyOwner {
        revert();
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
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        BicTokenPaymasterStorage.Data storage $ = BicTokenPaymasterStorage
            ._getStorageLocation();

        super._update(from, to, amount);

        require(!paused(), "BicTokenPaymaster: token transfer while paused");
        require(!$._isBlocked[from], "BicTokenPaymaster: sender is blocked");
    }

    /// @inheritdoc UUPSUpgradeable
    ///
    /// @dev Authorization logic is only based on the `msg.sender` being an owner of this account,
    ///      or `address(this)`.
    function _authorizeUpgrade(
        address
    ) internal view virtual override(UUPSUpgradeable) onlyOwner {}

    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 validationData) {
        _requireFromEntryPoint();
        console.log("validatePaymasterUserOp");
        return ("", 0);
    }

    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) external {
        _requireFromEntryPoint();
        console.log("postOp");
    }
}
