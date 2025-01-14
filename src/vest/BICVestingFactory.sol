// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BICVesting} from "./BICVesting.sol";
import {BICVestingErrors} from "../interfaces/BICVestingErrors.sol";

/// @title BicRedeemFactory for creating and managing ERC20 token redeems
/// @notice This contract allows users to create time-locked token redeem contracts
contract BICVestingFactory is Ownable, BICVestingErrors {
    /// @notice The denominator used for calculating percentages, 100% = 10_000, 10% = 1_000, 1% = 100, 0.1% = 10, 0.01% = 1
    /// @dev This is used to calculate the redeem rate
    uint64 public constant DENOMINATOR = 10_000;

    /// @notice Emitted when a new redeem contract is initialized
    /// @param redeem Address of the new redeem contract
    /// @param erc20 Address of the ERC20 token
    /// @param totalAmount Total amount of tokens to be redeemed over time
    /// @param beneficiaries Address of the beneficiary who is received the redeemed tokens
    /// @param allocations Address of the beneficiary who is received the redeemed tokens
    /// @param durationSeconds Duration of the redeem in seconds
    /// @param redeemRate Percentage of the total amount that is redeemed per duration
    event RedeemInitialized(
        address redeem,
        address erc20,
        uint256 totalAmount,
        address[] beneficiaries,
        uint16[] allocations,
        uint64 durationSeconds,
        uint64 redeemRate
    );

    /// @notice Address of the BICVesting implementation used for creating new clones
    /// @dev This is a clone factory pattern
    BICVesting public immutable bicVestingImplementation;

    /// @notice Mapping of beneficiary addresses to their redeem contract addresses
    /// @dev This is used to prevent multiple redeem contracts from being created for the same beneficiary
    /// @dev Each beneficiary can only have one redeem contract for only one type of token
    mapping(address => address) public redeemAddress;

    /// @notice Initializes the BicRedeemFactory contract
    /// @dev This sets the bicVestingImplementation to a new BICVesting instance
    constructor(address initialOwner) Ownable(initialOwner) {
        bicVestingImplementation = new BICVesting();
    }

    /// @notice Creates a new redeem contract for a beneficiary using the specified parameters
    /// @dev Deploys a clone of `bicVestingImplementation`, initializes it, and transfers the required tokens
    /// @param erc20 The address of the ERC20 token to lock
    /// @param totalAmount The total amount of tokens to lock
    /// @param beneficiaries The address of the beneficiary who can claim the tokens
    /// @param allocations The percentage of total tokens to allocate to each beneficiary
    /// @param durationSeconds The duration over which the tokens will redeem
    /// @param redeemRate The percentage of total tokens to redeem per interval
    /// @return ret The address of the newly created redeem token contract
    function createRedeem(
        address erc20,
        uint256 totalAmount,
        address[] calldata beneficiaries,
        uint16[] calldata allocations,
        uint64 durationSeconds,
        uint64 redeemRate
    ) public onlyOwner returns (BICVesting ret) {
        if (
            beneficiaries.length == 0 ||
            beneficiaries.length != allocations.length
        ) {
            revert InvalidRedeemAllocation(beneficiaries, allocations);
        }

        // validate beneficiaryAddresses and allocations
        _validateBeneficiaries(beneficiaries);
        _validateAllocations(allocations);

        if (
            totalAmount == 0 ||
            durationSeconds == 0 ||
            redeemRate == 0 ||
            redeemRate > DENOMINATOR ||
            erc20 == address(0)
        ) {
            revert InvalidVestingConfig(totalAmount, durationSeconds, redeemRate, erc20);
        }

        bytes32 salthash = getHash(erc20, totalAmount, beneficiaries, allocations, durationSeconds, redeemRate);

        ret = BICVesting(Clones.cloneDeterministic(address(bicVestingImplementation), salthash));
        ret.initialize(erc20, totalAmount, beneficiaries, allocations, uint64(block.timestamp), durationSeconds, redeemRate);

        // Transfer from BIC to Account
        SafeERC20.safeTransfer(IERC20(erc20), address(ret), totalAmount);

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            redeemAddress[beneficiaries[i]] = address(ret);
        }
        emit RedeemInitialized(address(ret), erc20, totalAmount, beneficiaries, allocations, durationSeconds, redeemRate);
    }


    /// @notice Computes the address of a potential redeem contract for a given set of parameters
    /// @param erc20 The address of the ERC20 token involved
    /// @param totalAmount The total amount of tokens potentially to lock
    /// @param beneficiaries The address of the potential beneficiary
    /// @param allocations The percentage of total tokens to allocate to each beneficiary
    /// @param durationSeconds The potential duration of the redeem
    /// @param redeemRate The percentage of total tokens to redeem at each interval
    /// @return predicted The address of the potential redeem contract
    function computeRedeem(
        address erc20,
        uint256 totalAmount,
        address[] calldata beneficiaries,
        uint16[] calldata allocations,
        uint64 durationSeconds,
        uint64 redeemRate
    ) public view returns (address) {
        if (
            beneficiaries.length == 0 ||
            beneficiaries.length != allocations.length
        ) {
            revert InvalidRedeemAllocation(beneficiaries, allocations);
        }

        // only need to validate allocations
        _validateAllocations(allocations);
        
        bytes32 salthash = getHash(erc20, totalAmount, beneficiaries, allocations, durationSeconds, redeemRate);

        address predicted = Clones.predictDeterministicAddress(address(bicVestingImplementation), salthash);

        return predicted;
    }

    /// @notice Computes a hash of the redeem parameters
    /// @dev This hash is used for creating deterministic addresses for clone contracts
    /// @param erc20 The address of the ERC20 token
    /// @param totalAmount The total amount of tokens
    /// @param beneficiaries The addresses of the beneficiary
    /// @param allocations The percentage of the total amount to allocate to each beneficiary
    /// @param durationSeconds The duration of the redeem
    /// @param redeemRate The percentage of the total amount to be redeemed per interval
    /// @return hash The computed hash of the parameters
    function getHash(
        address erc20,
        uint256 totalAmount,
        address[] calldata beneficiaries,
        uint16[] calldata allocations,
        uint64 durationSeconds,
        uint64 redeemRate
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(erc20, totalAmount, beneficiaries, allocations, durationSeconds, redeemRate));
    }

    /// @notice validate beneficiary addresses
    /// @dev Ensure all beneficiaries are not null address
    /// @param beneficiaries beneficiary addresses
    function _validateBeneficiaries(address[] calldata beneficiaries) internal view {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            for (uint256 j = i + 1; j < beneficiaries.length; j++) {
                if (beneficiaries[i] == beneficiaries[j]) {
                    revert DuplicateBeneficiary(beneficiaries[i]);
                }
            }
            if (beneficiaries[i] == address(0) || redeemAddress[beneficiaries[i]] != address(0)) {
                revert InvalidBeneficiary(beneficiaries[i]);
            }
        }
    }

    /// @notice validate total allocation
    /// @dev Ensure the total allocation equals to denominator (10_000)
    /// @param allocations beneficiaries' allocations
    function _validateAllocations(uint16[] calldata allocations) internal pure {
        uint16 totalAllocations = 0;
        for (uint256 i = 0; i < allocations.length; i++) {
            totalAllocations += allocations[i];
            if(totalAllocations > DENOMINATOR) {
                revert InvalidAllocations(allocations);
            }
        }
    }
}