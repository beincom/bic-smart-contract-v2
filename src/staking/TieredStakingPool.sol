// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract TieredStakingPool is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Structs
    struct Tier {
        uint256 maxTokens;
        uint256 annualInterestRate;
        uint256 lockDuration;
        uint256 totalStaked;
        uint256 maxRewardDuration;
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
    error InvalidInterestRate(uint256 interestRate);
    error ZeroLockDuration();
    error ZeroStakeAmount();
    error NotEnoughCapacityInTier();
    error InvalidStartIndex(uint256 tierIndex);
    error InvalidTierIndex(uint256 tierIndex);
    error ZeroWithdrawAmount();
    error InvalidLockDuration(uint256 lockDuration, uint256 maxRewardDuration);

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
        uint256 _lockDuration,
        uint256 _maxRewardDuration
    ) external onlyOwner {
        if (_annualInterestRate > 10000) {
            revert InvalidInterestRate(_annualInterestRate);
        }
        if (_lockDuration == 0) {
            revert ZeroLockDuration();
        }
        if (_lockDuration > _maxRewardDuration) {
            revert InvalidLockDuration(_lockDuration, _maxRewardDuration);
        }

        tiers.push(
            Tier({
                maxTokens: _maxTokens,
                annualInterestRate: _annualInterestRate,
                lockDuration: _lockDuration,
                maxRewardDuration: _maxRewardDuration,
                totalStaked: 0
            })
        );
        emit TierAdded(tiers.length - 1, _maxTokens, _annualInterestRate, _lockDuration);
    }

    /**
     * @notice Depositing tokens in the tiered staking pools
     * @param amount The amount of tokens staked in the tiered staking pools
     */
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
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
     * @notice Depositing tokens in the specific tiered staking pool
     * @param tierIndex The index of the tiered staking pool
     * @param amount The amount of tokens staked in the tiered staking pool
     */
    function depositIntoTier(uint256 tierIndex, uint256 amount) external nonReentrant whenNotPaused {
        if (tierIndex >= tiers.length) revert InvalidTierIndex(tierIndex);
        if (amount == 0) revert ZeroStakeAmount();

        Tier storage tier = tiers[tierIndex];
        uint256 available = tier.maxTokens - tier.totalStaked;
        if (amount > available) revert NotEnoughCapacityInTier();

        token.safeTransferFrom(msg.sender, address(this), amount);

        deposits[msg.sender].push(
            Deposit({
                amount: amount,
                tierIndex: tierIndex,
                depositTime: block.timestamp,
                withdrawn: false
            })
        );
        tier.totalStaked += amount;

        emit Deposited(msg.sender, amount, tierIndex);
    }

    /**
     * @notice Withdrawing staking tokens after the maturity
     * @param startIndex The start index to look up in the users' deposits
     * @param batchSize The size will be loop from the start index in the users' deposits
     */
    function withdrawBatch(uint256 startIndex, uint256 batchSize) external nonReentrant {
        Deposit[] storage userDeposits = deposits[msg.sender];

        if (startIndex >= userDeposits.length) {
            revert InvalidStartIndex(startIndex);
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
                    uint256 rewardDuration = block.timestamp - dep.depositTime > tier.maxRewardDuration
                        ? tier.maxRewardDuration
                        : block.timestamp - dep.depositTime;
                    uint256 interest = (dep.amount * tier.annualInterestRate * rewardDuration) / (365 days * 10000);
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
        if (totalPrincipal == 0) {
            revert ZeroWithdrawAmount();
        }
        uint256 payout = totalPrincipal + totalInterest;
        token.safeTransfer(msg.sender, payout);
        emit Withdrawn(msg.sender, totalPrincipal, totalInterest);
    }

    /**
     * @notice Withdrawing all staking tokens after the maturity
     */
    function withdrawAll() external nonReentrant whenNotPaused {
        Deposit[] storage userDeposits = deposits[msg.sender];
        uint256 totalPrincipal;
        uint256 totalInterest;

        for (uint256 i = 0; i < userDeposits.length; i++) {
            Deposit storage dep = userDeposits[i];
            if (!dep.withdrawn) {
                Tier storage tier = tiers[dep.tierIndex];
                if (block.timestamp >= dep.depositTime + tier.lockDuration) {
                    uint256 rewardDuration = block.timestamp - dep.depositTime > tier.maxRewardDuration
                        ? tier.maxRewardDuration
                        : block.timestamp - dep.depositTime;
                    uint256 interest = (dep.amount * tier.annualInterestRate * rewardDuration) / (365 days * 10000);
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

    /**
     * @notice Pause stake and deposit. For emergency use.
     * @dev Event already defined and emitted in Pausable.sol
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause stake and deposit.
     * @dev Event already defined and emitted in Pausable.sol
     */
    function unpause() public onlyOwner {
        _unpause();
    }
}