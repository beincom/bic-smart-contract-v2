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
contract BICVesting is Context, Initializable, ReentrancyGuard, BICVestingErrors {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct RedeemAllocation {
        address beneficiary;
        uint16 allocation;
        uint256 releasedAmount;
    }

    /**
     * @notice Data structure to hold all relevant vesting information
     * @dev This struct is used to store information about the vesting schedule and state.
     * @param erc20 The address of the ERC20 token contract.
     * @param redeemTotalAmount The total amount of tokens to be redeemed.
     * @param start The start time of the vesting period (timestamp).
     * @param end The end time of the vesting period (timestamp).
     * @param duration The duration of the vesting period in seconds.
     * @param maxRewardStacks The maximum number of reward stacks allowed.
     * @param currentRewardStacks The current number of reward stacks.
     * @param redeemRate The rate at which tokens are redeemed.
     * @param lastAtCurrentStack The timestamp of the last action at the current stack.
     * @param amountPerDuration The amount of tokens to be released per duration.
     * @param released The total amount of tokens that have been released.
     * @param beneficiaries The list of beneficiary addresses.
     * @param allocations The list of allocations corresponding to each beneficiary.
     * @param releasedAmounts The list of amounts released to each beneficiary.
     */
    struct Data {
        address erc20;
        uint256 redeemTotalAmount;
        uint64 start;
        uint64 end;
        uint64 duration;
        uint64 maxRewardStacks;
        uint64 currentRewardStacks;
        uint64 redeemRate;
        uint256 lastAtCurrentStack;
        uint256 amountPerDuration;
        uint256 released;
        RedeemAllocation[] redeemAllocations;
    }
      
    /// @notice Emitted when tokens are released to the beneficiary
    /// @param caller The address of the account that executed the release
    /// @param beneficiary The address of the beneficiary who received the tokens
    /// @param amount The amount of tokens released
    /// @param timestamp The block timestamp when the release occurred
    event ERC20Released(address caller, address beneficiary, uint256 amount, uint256 timestamp);

    /// @notice The denominator used for calculating percentages, 100% = 10_000, 10% = 1_000, 1% = 100, 0.1% = 10, 0.01% = 1
    /// @dev This is used to calculate the redeem rate
    uint64 public constant DENOMINATOR = 10_000;

    address public erc20;
    EnumerableSet.AddressSet private _beneficiaries;
    mapping(address => RedeemAllocation) private _redeemAllocations;

    uint256 public _released;
    uint256 public redeemTotalAmount;
    uint64 public start;
    uint64 public end;
    uint64 public duration;
    uint64 public maxRewardStacks;
    uint64 public currentRewardStacks;
    uint64 public redeemRate;

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


        start = startTime;
        duration = durationSeconds;
        erc20 = erc20Address;
        redeemTotalAmount = totalAmount;
        maxRewardStacks = DENOMINATOR / redeemRateNumber;
        redeemRate = redeemRateNumber;
        end = start + maxRewardStacks * durationSeconds;
        if (DENOMINATOR % redeemRateNumber > 0) {
            end += 1 * durationSeconds;
        }

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address _beneficiary = beneficiaries[1];
            _beneficiaries.add(_beneficiary);
            _redeemAllocations[_beneficiary] = RedeemAllocation({
                beneficiary: _beneficiary,
                allocation: allocations[i],
                releasedAmount: 0
            });
        }
    }

    /// @notice Getter for all vesting information
    /// @dev This function returns all relevant vesting information in a single call
    /// @return The Data struct containing all vesting information
    function getInformation() 
        public 
        view 
        virtual 
        returns (Data memory) 
    {
        
        uint256 length = _beneficiaries.length();
        RedeemAllocation[] memory redeemAllocations = new RedeemAllocation[](length);
        for (uint256 i = 0; i < length; i++) {
            address beneficiaryAddress = _beneficiaries.at(i);
            redeemAllocations[i] = _redeemAllocations[beneficiaryAddress];
        }

        return Data({
            erc20: erc20,
            redeemTotalAmount: redeemTotalAmount,
            start: start,
            end: end,
            duration: duration,
            maxRewardStacks: maxRewardStacks,
            currentRewardStacks: currentRewardStacks,
            lastAtCurrentStack: _lastAtCurrentStack(),
            amountPerDuration: _amountPerDuration(),
            redeemRate: redeemRate,
            released: _released,
            redeemAllocations: redeemAllocations
        });
    }
    
    /// @notice Getter for the amount of tokens that will be released per duration
    /// @dev This function returns the amount of tokens that will be released per duration
    function amountPerDuration() public view virtual returns (uint256) {
        return _amountPerDuration();
    }

    /// @notice Getter for the beneficiary address
    /// @dev This function returns the address of the beneficiary who will receive the tokens after vesting
    function getBeneficiaries() public view virtual returns (address[] memory) {
        return _beneficiaries.values();
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
        currentRewardStacks += uint64(counter);
        _released += amount;
        
        for (uint256 i = 0; i < _beneficiaries.length(); i++) {
            _releaseToBeneficiary(_beneficiaries.at(i), amount);
        }
    }

    /// @dev Internal function to calculate the vesting schedule and determine releasable amount and reward stacks
    /// @param timestamp The current block timestamp
    /// @return amount The amount of tokens that can be released at this timestamp
    /// @return counter The number of reward stacks that have been released at this timestamp
    function _vestingSchedule(uint64 timestamp) internal view virtual returns (uint256, uint256) {
        if (timestamp < start) {
            return (0, 0);
        } else if (timestamp > end) {
            return (IERC20(erc20).balanceOf(address(this)), maxRewardStacks - currentRewardStacks);
        } else {
            // check for the latest stack, if currentRewardStacks < maxRewardStacks => amount is _amountPerDuration
            // for odd left-over in the last stack, wait for the end of the duration
            if (currentRewardStacks >= maxRewardStacks) return (0, 0);

            uint256 elapsedTime = uint256(timestamp) - _lastAtCurrentStack();
            uint256 rewardStackCounter = elapsedTime / duration;
            uint256 amount = rewardStackCounter * _amountPerDuration();

            return (amount, rewardStackCounter);
        }
    }

    /// @dev Internal helper function to calculate the amount of tokens per duration
    /// @return The calculated amount of tokens that should be released per duration based on the total amount and redeem rate
    function _amountPerDuration() internal view virtual returns (uint256) {
        return redeemTotalAmount * redeemRate / DENOMINATOR;
    }

    /// @dev Internal helper function to calculate the last timestamp at which tokens were released based on the current reward stacks
    /// @return The timestamp of the last release
    function _lastAtCurrentStack() internal view virtual returns (uint256) {
        return start + (duration * currentRewardStacks);
    }

    function _releaseToBeneficiary(address _beneficiary, uint256 stackAmount) private {
        RedeemAllocation storage _redeemAllocation = _redeemAllocations[_beneficiary];
        uint256 _releasedAmount = (stackAmount * _redeemAllocation.allocation) / DENOMINATOR;
        uint256 currentAllocation = _redeemAllocation.releasedAmount + _releasedAmount;
        uint256 maxAllocation = (redeemTotalAmount * _redeemAllocation.allocation) / DENOMINATOR;
        if (currentAllocation > maxAllocation) {
            revert ExceedAllocation(maxAllocation, currentAllocation);
        }
        _redeemAllocation.releasedAmount += _releasedAmount;
        SafeERC20.safeTransfer(IERC20(erc20), _beneficiary, _releasedAmount);
        emit ERC20Released(_msgSender(), _beneficiary, _releasedAmount, block.timestamp);
    }
}