// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TierStaking is Ownable {
    struct Tier {
        uint256 maxTokens;
        uint256 annualInterestRate;
        uint256 lockDuration;
        uint256 totalStaked;
    }
    mapping(uint8 => Tier) public tiers;
    uint8 public currentTierIndex;

    struct StakeInfo {
        uint256 amount;
        uint8 tierIndex;
        uint256 startTime;
    }
    mapping(address => StakeInfo[]) public userStakes;

    IERC20 public token;

    event Staked(address indexed user, uint256 amount, uint256 tierIndex);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(address _token, address _owner) Ownable(_owner) {
        token = IERC20(_token);
    }

    function setupTier(
        uint8 _tierIndex,
        uint256 _maxTokens,
        uint256 _annualInterestRate,
        uint256 _lockDuration
    ) external onlyOwner {
        if (tiers[_tierIndex].totalStaked > 0) {
            tiers[_tierIndex] = Tier(
                tiers[_tierIndex].maxTokens == tiers[_tierIndex].totalStaked
                    ? tiers[_tierIndex].maxTokens
                    : _maxTokens,
                _annualInterestRate,
                _lockDuration,
                tiers[_tierIndex].totalStaked
            );
        } else {
            tiers[_tierIndex] = Tier(
                _maxTokens,
                _annualInterestRate,
                _lockDuration,
                0
            );
        }
    }

    function stake(uint256 _amount) external {
        if (_amount == 0) {
            return;
        }
        if (tiers[currentTierIndex].maxTokens == 0) {
            return;
        }
        token.transferFrom(msg.sender, address(this), _amount);

        uint256 remaining = _amount;
        while (remaining > 0 && tiers[currentTierIndex].maxTokens > tiers[currentTierIndex].totalStaked) {
            Tier storage currentTier = tiers[currentTierIndex];
            uint256 available = currentTier.maxTokens - currentTier.totalStaked;

            if (available == 0) {
                currentTierIndex++;
                continue;
            }

            uint256 stakeInTier = (remaining <= available) ? remaining : available;
            userStakes[msg.sender].push(StakeInfo(stakeInTier, currentTierIndex, block.timestamp));
            currentTier.totalStaked += stakeInTier;
            remaining -= stakeInTier;

            emit Staked(msg.sender, stakeInTier, currentTierIndex);

            if (currentTier.totalStaked == currentTier.maxTokens) {
                currentTierIndex++;
            }
        }
    }

    function withdraw(uint256 _stakeId) external {
        StakeInfo storage stakeInfo = userStakes[msg.sender][_stakeId];
        require(block.timestamp >= stakeInfo.startTime + tiers[stakeInfo.tierIndex].lockDuration, "Lock period not ended");

        uint256 interest = (stakeInfo.amount * tiers[stakeInfo.tierIndex].annualInterestRate * tiers[stakeInfo.tierIndex].lockDuration) / (365 days * 10000);
        uint256 total = stakeInfo.amount + interest;

        tiers[stakeInfo.tierIndex].totalStaked -= stakeInfo.amount;
        delete userStakes[msg.sender][_stakeId];

        token.transfer(msg.sender, total);
        emit Withdrawn(msg.sender, total);
    }
}