// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TieredStakingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Structs
    struct Tier {
        uint256 maxTokens;
        uint256 annualInterestRate;
        uint256 lockDuration;
        uint256 totalStaked;
    }

    struct Deposit {
        uint256 amount;
        uint256 tierIndex;
        uint256 depositTime;
        bool withdrawn;
    }

    IERC20 public token;
    Tier[] public tiers;
    mapping(address => Deposit[]) public deposits;

    // Events

    /// @notice Emitted when adding a new tiered staking pool
    event TierAdded(uint256 indexed tierIndex, uint256 maxTokens, uint256 annualInterestRate, uint256 lockDuration);
    /// @notice Emitted when depositing staking in the tiered staking pool
    event Deposited(address indexed user, uint256 amount, uint256 tierIndex);
    /// @notice Emitted when unlocking staking in the tiered staking pool after the maturity
    event Withdrawn(address indexed user, uint256 principal, uint256 interest);

    // Errors
    error ZeroAddress();
    error InvalidInterestRate();
    error InvalidLockDuration();
    error ZeroStakeAmount();
    error NotEnoughCapacityInTier();
    error InvalidStartIndex();
    error ZeroWithdrawAmount();

    constructor(IERC20 _token, address _owner) Ownable(_owner) {
        if (address(_token) == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }
        token = _token;
    }

    /**
     * @notice Getting all tiered staking pools
     */
    function getTiers() external view returns (Tier[] memory) {
        return tiers;
    }

    /**
     * @notice Getting all users' deposits
     * @param user The user address
     */
    function getUserDeposits(address user) external view returns (Deposit[] memory) {
        return deposits[user];
    }

    /**
     * @notice Added a tiered staking pool
     * @param _maxTokens The maximum tokens can be staked in the tiered staking pool
     * @param _annualInterestRate The percentage of annual interest rate
     * @param _lockDuration The period time of staking
     */
    function addTier(
        uint256 _maxTokens,
        uint256 _annualInterestRate,
        uint256 _lockDuration
    ) external onlyOwner {
        if (_annualInterestRate > 10000) {
            revert InvalidInterestRate();
        }
        if (_lockDuration == 0) {
            revert InvalidLockDuration();
        }

        tiers.push(
            Tier({
                maxTokens: _maxTokens,
                annualInterestRate: _annualInterestRate,
                lockDuration: _lockDuration,
                totalStaked: 0
            })
        );
        emit TierAdded(tiers.length - 1, _maxTokens, _annualInterestRate, _lockDuration);
    }

    /**
     * @notice Depositing tokens in the tiered staking pools
     * @param amount The amount of tokens staked in the tiered staking pools
     */
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) {
            revert ZeroStakeAmount();
        }
        token.safeTransferFrom(msg.sender, address(this), amount);

        uint256 remaining = amount;
        for (uint256 i = 0; i < tiers.length && remaining > 0; i++) {
            Tier storage tier = tiers[i];
            uint256 available = tier.maxTokens - tier.totalStaked;
            uint256 depositInTier = remaining <= available ? remaining : available;
            if (depositInTier > 0) {
                deposits[msg.sender].push(
                    Deposit({
                        amount: depositInTier,
                        tierIndex: i,
                        depositTime: block.timestamp,
                        withdrawn: false
                    })
                );
                tier.totalStaked += depositInTier;
                remaining -= depositInTier;
                emit Deposited(msg.sender, depositInTier, i);
            }
        }
        if (remaining > 0) {
            revert NotEnoughCapacityInTier();
        }
    }

    /**
     * @notice Withdrawing staking tokens after the maturity
     * @param startIndex The start index to look up in the users' deposits
     * @param batchSize The size will be loop from the start index in the users' deposits
     */
    function withdrawBatch(uint256 startIndex, uint256 batchSize) external nonReentrant {
        Deposit[] storage userDeposits = deposits[msg.sender];

        if (startIndex >= userDeposits.length) {
            revert InvalidStartIndex();
        }
        uint256 totalPrincipal;
        uint256 totalInterest;
        uint256 processed = 0;
        uint256 end = userDeposits.length;

        uint256 limit = startIndex + batchSize;
        if (limit < end) {
            end = limit;
        }

        for (uint256 i = startIndex; i < end; i++) {
            Deposit storage dep = userDeposits[i];
            if (!dep.withdrawn) {
                Tier storage tier = tiers[dep.tierIndex];
                if (block.timestamp >= dep.depositTime + tier.lockDuration) {
                    uint256 interest = (dep.amount * tier.annualInterestRate * tier.lockDuration) / (365 days * 10000);
                    totalPrincipal += dep.amount;
                    totalInterest += interest;
                    dep.withdrawn = true;

                    if (tier.totalStaked >= dep.amount) {
                        tier.totalStaked -= dep.amount;
                    } else {
                        tier.totalStaked = 0;
                    }
                    processed++;
                }
            }
        }
        if (totalInterest == 0) {
            revert ZeroWithdrawAmount();
        }
        uint256 payout = totalPrincipal + totalInterest;
        token.safeTransfer(msg.sender, payout);
        emit Withdrawn(msg.sender, totalPrincipal, totalInterest);
    }

    /**
     * @notice Withdrawing all staking tokens after the maturity
     */
    function withdrawAll() external nonReentrant {
        Deposit[] storage userDeposits = deposits[msg.sender];
        uint256 totalPrincipal;
        uint256 totalInterest;

        for (uint256 i = 0; i < userDeposits.length; i++) {
            Deposit storage dep = userDeposits[i];
            if (!dep.withdrawn) {
                Tier storage tier = tiers[dep.tierIndex];
                if (block.timestamp >= dep.depositTime + tier.lockDuration) {
                    uint256 interest = (dep.amount * tier.annualInterestRate * tier.lockDuration) / (365 days * 10000);
                    totalPrincipal += dep.amount;
                    totalInterest += interest;
                    dep.withdrawn = true;
                    if (tier.totalStaked >= dep.amount) {
                        tier.totalStaked -= dep.amount;
                    } else {
                        tier.totalStaked = 0;
                    }
                }
            }
        }
        if (totalPrincipal == 0) {
            revert ZeroWithdrawAmount();
        }
        uint256 payout = totalPrincipal + totalInterest;
        token.safeTransfer(msg.sender, payout);
        emit Withdrawn(msg.sender, totalPrincipal, totalInterest);
    }
}