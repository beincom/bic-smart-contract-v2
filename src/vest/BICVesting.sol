// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {BICVestingErrors} from "../interfaces/BICVestingErrors.sol";

/// @title BICVesting Contract
/// @notice Manages the locked tokens, allowing beneficiaries to claim their tokens after a vesting period
/// @dev This contract uses OpenZeppelin's Initializable and ReentrancyGuard to provide initialization and reentrancy protection
/// @dev Based on VestingWallet from OpenZeppelin Contracts
contract BICVesting is
    Context,
    Initializable,
    ReentrancyGuard,
    BICVestingErrors
{
    using EnumerableSet for EnumerableSet.AddressSet;

    struct RedeemAllocation {
        address beneficiary;
        uint16 allocation;
        uint256 releasedAmount;
    }

    /// @notice Emitted when tokens are released to the beneficiary
    /// @param caller The address of the account that executed the release
    /// @param beneficiary The address of the beneficiary who received the tokens
    /// @param amount The amount of tokens released
    /// @param timestamp The block timestamp when the release occurred
    event ERC20Released(
        address caller,
        address beneficiary,
        uint256 amount,
        uint256 timestamp
    );

    /// @notice The denominator used for calculating percentages, 100% = 10_000, 10% = 1_000, 1% = 100, 0.1% = 10, 0.01% = 1
    /// @dev This is used to calculate the redeem rate
    uint64 public constant DENOMINATOR = 10_000;

    address private _erc20;
    EnumerableSet.AddressSet private _beneficiaries;
    mapping(address => RedeemAllocation) private _redeemAllocations;

    uint256 private _released;
    uint256 private _totalAmount;
    uint64 private _start;
    uint64 private _end;
    uint64 private _duration;
    uint64 private _maxRewardStacks;
    uint64 private _currentRewardStacks;
    uint64 private _redeemRate;

    /// @dev Constructor is empty and payment is disabled by default
    constructor() payable {}

    /// @notice Initializes the contract with necessary parameters to start the vesting process
    /// @dev Ensure all parameters are valid, particularly that addresses are not zero and amounts are positive
    /// @param erc20Address The ERC20 token address to be locked in the contract
    /// @param totalAmount The total amount of tokens that will be locked
    /// @param beneficiaries The address of the beneficiary who will receive the tokens after vesting
    /// @param allocations The percentage of the total amount that will be allocated to each beneficiary
    /// @param startTime The start time of the vesting period if it is in the future then released amount will be 0
    /// @param durationSeconds The duration of the vesting period in seconds
    /// @param redeemRateNumber The rate at which the tokens will be released per duration
    function initialize(
        address erc20Address,
        uint256 totalAmount,
        address[] calldata beneficiaries,
        uint16[] calldata allocations,
        uint64 startTime,
        uint64 durationSeconds,
        uint64 redeemRateNumber
    ) public virtual initializer {
        _start = startTime;
        _duration = durationSeconds;
        _erc20 = erc20Address;
        _totalAmount = totalAmount;
        _maxRewardStacks = DENOMINATOR / redeemRateNumber;
        _redeemRate = redeemRateNumber;
        _end = _start + _maxRewardStacks * durationSeconds;
        if (DENOMINATOR % redeemRateNumber > 0) {
            _end += 1 * durationSeconds;
        }

        // Check for duplicate beneficiaries
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            for (uint256 j = i + 1; j < beneficiaries.length; j++) {
                if (beneficiaries[i] == beneficiaries[j]) {
                    revert DuplicateBeneficiary(beneficiaries[i]);
                }
            }
            address _beneficiary = beneficiaries[i];
            _beneficiaries.add(_beneficiary);
            _redeemAllocations[_beneficiary] = RedeemAllocation({
                beneficiary: _beneficiary,
                allocation: allocations[i],
                releasedAmount: 0
            });
        }
    }

    /// @notice Getter for the ERC20 token address
    /// @dev This function returns the address of the ERC20 token that is locked in the contract
    function erc20() public view virtual returns (address) {
        return _erc20;
    }

    /// @notice Getter for the total amount of tokens locked in the contract
    /// @dev This function returns the total amount of tokens that are locked in the contract
    function redeemTotalAmount() public view virtual returns (uint256) {
        return _totalAmount;
    }

    /// @notice Getter for the redeem rate
    /// @dev This function returns the redeem rate, which is the percentage of tokens that will be released per duration
    function redeemRate() public view virtual returns (uint64) {
        return _redeemRate;
    }

    /// @notice Getter for the beneficiary address
    /// @dev This function returns the address of the beneficiary who will receive the tokens after vesting
    function getBeneficiaries() public view virtual returns (address[] memory) {
        return _beneficiaries.values();
    }

    /// @notice Getter for the start timestamp
    /// @dev This function returns the start timestamp of the vesting period
    function start() public view virtual returns (uint256) {
        return _start;
    }

    /// @notice Getter for the end timestamp
    /// @dev This function returns the end timestamp of the vesting period
    function end() public view virtual returns (uint256) {
        return _end;
    }

    /// @notice Getter for the duration of the vesting period
    /// @dev This function returns the duration of the vesting period
    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    /// @notice Getter for the last timestamp at the current reward stack
    /// @dev This function returns the last timestamp at the current reward stack
    function lastAtCurrentStack() public view virtual returns (uint256) {
        return _lastAtCurrentStack();
    }

    /// @notice Getter for the maximum reward stacks
    /// @dev This function returns the maximum reward stacks
    function maxRewardStacks() public view virtual returns (uint256) {
        return _maxRewardStacks;
    }

    /// @notice Getter for the current reward stacks
    /// @dev This function returns the current reward stacks
    function currentRewardStacks() public view virtual returns (uint256) {
        return _currentRewardStacks;
    }

    /// @notice Getter for the amount of tokens that will be released per duration
    /// @dev This function returns the amount of tokens that will be released per duration
    function amountPerDuration() public view virtual returns (uint256) {
        return _amountPerDuration();
    }

    /// @notice Getter for the amount of tokens that have been released
    /// @dev This function returns the amount of tokens that have been released to the beneficiary
    function released() public view virtual returns (uint256) {
        return _released;
    }

    /// @notice Calculates the amount of tokens that are currently available for release
    /// @dev This function uses the vesting formula to calculate the amount of tokens that can be released
    function releasable() public view virtual returns (uint256, uint256) {
        return _vestingSchedule(uint64(block.timestamp));
    }

    /// @notice Allows the beneficiary to release vested tokens
    /// @dev This function includes checks for the amount of tokens available for release token and updates internal states
    function release() public virtual nonReentrant {
        (uint256 amount, uint256 counter) = releasable();
        if (amount == 0) {
            revert NoRelease();
        }
        _currentRewardStacks += uint64(counter);
        _released += amount;

        for (uint256 i = 0; i < _beneficiaries.length(); i++) {
            _releaseToBeneficiary(_beneficiaries.at(i), amount);
        }
    }

    /// @dev Internal function to calculate the vesting schedule and determine releasable amount and reward stacks
    /// @param timestamp The current block timestamp
    /// @return amount The amount of tokens that can be released at this timestamp
    /// @return counter The number of reward stacks that have been released at this timestamp
    function _vestingSchedule(
        uint64 timestamp
    ) internal view virtual returns (uint256, uint256) {
        if (timestamp < _start) {
            return (0, 0);
        } else if (timestamp > _end) {
            return (
                IERC20(_erc20).balanceOf(address(this)),
                _maxRewardStacks - _currentRewardStacks
            );
        } else {
            // check for the latest stack, if _currentRewardStacks < _maxRewardStacks => amount is _amountPerDuration
            // for odd left-over in the last stack, wait for the end of the duration
            if (_currentRewardStacks >= _maxRewardStacks) return (0, 0);

            uint256 elapsedTime = uint256(timestamp) - _lastAtCurrentStack();
            uint256 rewardStackCounter = elapsedTime / _duration;
            uint256 amount = rewardStackCounter * _amountPerDuration();

            return (amount, rewardStackCounter);
        }
    }

    /// @dev Internal helper function to calculate the amount of tokens per duration
    /// @return The calculated amount of tokens that should be released per duration based on the total amount and redeem rate
    function _amountPerDuration() internal view virtual returns (uint256) {
        return (_totalAmount * _redeemRate) / DENOMINATOR;
    }

    /// @dev Internal helper function to calculate the last timestamp at which tokens were released based on the current reward stacks
    /// @return The timestamp of the last release
    function _lastAtCurrentStack() internal view virtual returns (uint256) {
        return _start + (_duration * _currentRewardStacks);
    }

    function _releaseToBeneficiary(
        address _beneficiary,
        uint256 stackAmount
    ) private {
        RedeemAllocation storage _redeemAllocation = _redeemAllocations[
            _beneficiary
        ];
        uint256 _releasedAmount = (stackAmount * _redeemAllocation.allocation) /
            DENOMINATOR;
        uint256 currentAllocation = _redeemAllocation.releasedAmount +
            _releasedAmount;
        uint256 maxAllocation = (_totalAmount * _redeemAllocation.allocation) /
            DENOMINATOR;
        if (currentAllocation > maxAllocation) {
            revert ExceedAllocation(maxAllocation, currentAllocation);
        }
        _redeemAllocation.releasedAmount += _releasedAmount;
        SafeERC20.safeTransfer(IERC20(_erc20), _beneficiary, _releasedAmount);
        emit ERC20Released(
            _msgSender(),
            _beneficiary,
            _releasedAmount,
            block.timestamp
        );
    }
}
