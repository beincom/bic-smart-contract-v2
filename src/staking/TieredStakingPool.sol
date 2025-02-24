// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract TieredStakingPool is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public token;

    struct Tier {
        uint256 maxTokens;
        uint256 annualInterestRate;
        uint256 lockDuration;
        uint256 totalStaked;
    }

    Tier[] public tiers;

    struct Deposit {
        uint256 amount;
        uint256 tierIndex;
        uint256 depositTime;
        bool withdrawn;
    }

    mapping(address => Deposit[]) public deposits;

    event TierAdded(uint256 indexed tierIndex, uint256 maxTokens, uint256 annualInterestRate, uint256 lockDuration);
    event Deposited(address indexed user, uint256 amount, uint256 tierIndex);
    event Withdrawn(address indexed user, uint256 principal, uint256 interest);

    error ZeroTokenAddress();
    error ZeroStakeAmount();
    error NotEnoughCapacityInTier();
    error ZeroWithdrawAmount();

    constructor(IERC20 _token, address _owner) Ownable(_owner) {
        if (address(_token) == address(0)) {
            revert ZeroTokenAddress();
        }
        token = _token;
    }

    function addTier(
        uint256 _maxTokens,
        uint256 _annualInterestRate,
        uint256 _lockDuration
    ) external onlyOwner {
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

    function depositIntoTier(uint256 tierIndex, uint256 amount) external nonReentrant whenNotPaused {
        if (tierIndex >= tiers.length) revert("Invalid tier index");
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

    function withdrawBatch(uint256 startIndex, uint256 batchSize) external nonReentrant whenNotPaused {
        Deposit[] storage userDeposits = deposits[msg.sender];
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
        if (totalPrincipal == 0) {
            revert ZeroWithdrawAmount();
        }
        uint256 payout = totalPrincipal + totalInterest;
        token.safeTransfer(msg.sender, payout);
        emit Withdrawn(msg.sender, totalPrincipal, totalInterest);
    }

    function withdrawAll() external nonReentrant whenNotPaused {
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

    function getTiers() external view returns (Tier[] memory) {
        return tiers;
    }

    function getUserDeposits(address user) external view returns (Deposit[] memory) {
        return deposits[user];
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
}