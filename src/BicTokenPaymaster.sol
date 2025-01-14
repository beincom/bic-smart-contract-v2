// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {SafeMath} from "./utils/math/SafeMath.sol";
import {TokenSingletonPaymaster} from "./base/TokenSingletonPaymaster.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BICErrors} from "./interfaces/BICErrors.sol";

contract BicTokenPaymaster is
    TokenSingletonPaymaster,
    Pausable,
    BICErrors
{
    using SafeMath for uint256;

    /// DEX Pre-public
    /// Pre-public structure
    struct PrePublic {
        uint256 category;
        uint256 startTime;
        uint256 endTime;
        uint256 coolDown;
        uint256 maxAmountPerBuy;
    }

    /// Enabled DEX pre-public
    bool private _prePublic;
    
    /// Liquidity fee
    /// The start time to calculate liquidity fee reduction
    uint256 public LFStartTime;

    /// The liquidity fee reducted after a specific period of time
    uint public LFReduction;

    /// The period of liquidity fee reduction
    uint256 public LFPeriod;

    /// Liquidity fee reduction enable
    bool public isEnabledLFReduction;

    /// liquidity fee
    uint256 public maxLF;
    uint256 public minLF;


    
    /// swap back and liquify
    /// Uniswap V2 router
    address public immutable uniswapV2Router;

    /// Uniswap V2 pair
    address public uniswapV2Pair;
    
    /// Accumulated liquidity fee
    uint256 public accumulatedLF;
    
    /// Liquidity treasury
    address public liquidityTreasury;

    /// Swap back and liquify threshold
    uint256 public minSwapBackAmount;

    /// Swap back enabled
    bool public swapBackEnabled;

    /// Guard _swapping
    bool private _swapping;

    
    /// Whitelist for pre-public in DEX
    mapping(address => uint256) private _prePublicWhitelist;

    /// Cooldown in Pre-public round in DEX
    mapping(address => uint256) private _coolDown;

    /// Pre-public round in DEX
    mapping(uint256 => PrePublic) public prePublicRounds;

    /// excluded from liquidity fee
    mapping(address => bool) public isExcluded;

    /// whitelist pools to charge liquidity fee on
    mapping(address => bool) public isPool;

    /// The blocked users
    mapping (address => bool) public isBlocked;

    // EVENTS
    /// @dev Emitted when changing a pre-public status
    event PrePublicStatusUpdated(address indexed updater, bool status);

    /// @dev Emitted when changing a pre-public whitelist
    event PrePublicWhitelistUpdated(
        address indexed updater,
        address[] addresses,
        uint256[] categories
    );

    /// @dev Emitted when changing a specific pre-public round info
    event PrePublicRoundUpdated(address indexed updater, uint256 indexed category);

    /// @dev Emitted when swap back and liquify
    event SwapBackAndLiquify(uint256 liquidityTokens, uint256 ETHForLiquidity);

    /// @dev Emitted when changing swap back enabled status
    event SwapBackEnabledUpdated(address indexed updater, bool status);

    /// @dev Emitted when chaning min swap back amount
    event MinSwapBackAmountUpdated(address indexed updater, uint256 amount);

    /// @dev Emitted when changing liquidity fee
    event LiquidityFeeUpdated(address indexed updater, uint256 min, uint256 max);

    /// @dev Emitted when updating excluded address
    event ExcludedUpdated(address indexed excludedAddress, bool status);

    /// @dev Emitted when updating LP pools
    event PoolUpdated(address indexed updater, address indexed pool, bool status);

    /// @dev Emitted when updating blacklist
    event BlockUpdated(address indexed updater, address indexed addr, bool status);

    /// @dev Emitted when liquidity fee interval step is upadted
    event LFReductionUpdated(address indexed updater, uint256 _LFReduction);

    /// @dev Emitted when changing liquidity fee period
    event LFPeriodUpdated(address indexed updater, uint256 LFPeriod);

    /// @dev Emitted when changing LF start time
    event LFStartTimeUpdated(uint256 _newLFStartTime);

    /// @dev Emitted when changing liquidity treasury
    event LiquidityTreasuryUpdated(address indexed updater, address indexed newLFTreasury);

    constructor(
        address _entryPoint,
        address superController,
        address[] memory _signers
    ) ERC20("Beincom", "BIC") EIP712("beincom", "1") TokenSingletonPaymaster(_entryPoint, _signers) Ownable(_msgSender()) {
        uint256 _totalSupply = 5 * 1e27;
        _mint(superController, _totalSupply);

        liquidityTreasury = superController;

        maxLF = 1500;
        minLF = 300;
        LFReduction = 50;
        LFPeriod = 60 * 60 * 24 * 30; // 30 days
        LFStartTime = block.timestamp;
        isExcluded[superController] = true;
        isExcluded[address(this)] = true;

        _prePublic = true;

        swapBackEnabled = true;
        minSwapBackAmount = _totalSupply.div(10000);

        uniswapV2Router = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
        uniswapV2Pair = IUniswapV2Factory(
            IUniswapV2Router02(uniswapV2Router).factory()
        ).createPair(
                address(this),
                IUniswapV2Router02(uniswapV2Router).WETH()
            );
        _setPool(uniswapV2Pair, true);

        transferOwnership(superController);
    }

    /**
     * @notice Get whitelist category.
     * @param user user address.
     */
    function getWhitelistCategory(address user) public view returns (uint256) {
        return _prePublicWhitelist[user];
    }

    /**
     * @notice Get current liquidity fee
     * @return current liquidity fee
     */
    function getCurrentLF() public view returns (uint256) {
        uint256 totalReduction = block
            .timestamp
            .sub(LFStartTime)
            .div(LFPeriod)
            .mul(LFReduction);

        if (totalReduction + minLF >= maxLF) {
            return minLF;
        } else {
            return maxLF.sub(totalReduction);
        }
    }

    // PRE-PUBLIC MANAGEMENT FUNCTIONS
    /**
     * @notice Updated pre-public status.
     * @param status pre-public status.
     */
    function setPrePublic(bool status) external onlyOwner {
        _prePublic = status;
        emit PrePublicStatusUpdated(_msgSender(), status);
    }

    /**
     * @notice Updated pre-public whitelist info.
     * @param addresses whitelist addresses.
     * @param categories category in DEX pre-public.
     */
    function setPrePublicWhitelist(
        address[] memory addresses,
        uint256[] memory categories
    ) external onlyOwner {
        _setPrePublicWhitelist(addresses, categories);
    }

    /**
     * @notice Updated pre-public round info.
     * @param prePublicRound Pre-public round info.
     */
    function setPrePublicRound(
        PrePublic memory prePublicRound
    ) external onlyOwner {
        _setPrePublicRound(prePublicRound);
    }

    // LIQUIDITY FEE MANAGEMENT FUNCTIONS
    /**
     * @notice Update liquidity fee start time
     * @param _newLFStartTime new liquidity fee start time
     */
    function setLFStartTime(uint256 _newLFStartTime) external onlyOwner {
        if (_newLFStartTime < block.timestamp) {
            revert BICInvalidLFStartTime(_newLFStartTime);
        }
        LFStartTime = _newLFStartTime;
        emit LFStartTimeUpdated(_newLFStartTime);
    }

    /**
     * @notice Update liquidity treasury.
     * @param newLFTreasury new liquidity treasury.
     */
    function setLiquidityTreasury(address newLFTreasury) external onlyOwner {
        liquidityTreasury = newLFTreasury;
        emit LiquidityTreasuryUpdated(_msgSender(), newLFTreasury);
    }

    /**
     * @notice Update liquidity fee.
     * @param max max liquidity fee basic points.
     * @param min min liquidity fee basic points.
     */
    function setLiquidityFee(uint256 min, uint256 max) external onlyOwner {
        if (min < 0 || min > max || max > 5000) {
            revert BICInvalidMinMaxLF(min, max);
        }
        minLF = min;
        maxLF = max;
        emit LiquidityFeeUpdated(_msgSender(), min, max);
    }

    /**
     * @notice Update liquidity fee reduction
     * @param _LFReduction liquidity fee reduction percent
     */
    function setLFReduction(uint256 _LFReduction) external onlyOwner {
        if (_LFReduction <= 0) {
            revert BICLFReduction(_LFReduction);
        }
        LFReduction = _LFReduction;
        emit LFReductionUpdated(_msgSender(), _LFReduction);
    }

    /**
     * @notice Update liquidity fee period
     * @param _LFPeriod liquidity fee period
     */
    function setLFPeriod(uint256 _LFPeriod) external onlyOwner {
        if (_LFPeriod <= 0) {
            revert BICLFPeriod(_LFPeriod);
        }
        LFPeriod = _LFPeriod;
        emit LFPeriodUpdated(_msgSender(), _LFPeriod);
    }

    // SWAP BACK MANAGEMENT FUNCTIONS
    /**
     * @notice Update swap back enabled status.
     * @param status swap back enabled status.
     */
    function setSwapBackEnabled(bool status) external onlyOwner {
        swapBackEnabled = status;
        emit SwapBackEnabledUpdated(_msgSender(), status);
    }

    /**
     * @notice Update min swap back amount.
     * @param amount min swap back amount.
     */
    function setMinSwapBackAmount(uint256 amount) external onlyOwner {
        minSwapBackAmount = amount;
        emit MinSwapBackAmountUpdated(_msgSender(), amount);
    }

    // POOL MANAGEMENT FUNCTIONS
    /**
     * @notice Updated status of LP pool.
     * @param pool pool address.
     * @param status status of the pool.
     */
    function setPool(address pool, bool status) external onlyOwner {
        _setPool(pool, status);
    }

    /**
     * @notice Updated status of excluded addresses.
     * @param excludedAddresses excluded addresses
     * @param status status of excluded address
     */
    function bulkExcluded(
        address[] memory excludedAddresses,
        bool status
    ) external onlyOwner {
        for (uint256 i = 0; i < excludedAddresses.length; i++) {
            _setisExcluded(excludedAddresses[i], status);
        }
    }

    // TREASURY MANAGEMENT FUNCTIONS
    /**
     * @notice Withdraw stuck token.
     * @param token token address.
     * @param to beneficiary address.
     */
    function withdrawStuckToken(
        address token,
        address to,
        uint256 amount
    ) public onlyOwner {
        bool success;
        if (token == address(0)) {
            (success, ) = address(to).call{value: amount}("");
        } else {
            ERC20(token).transfer(to, amount);
        }
    }

    /**
     * @notice Block malicious address.
     * @param addr blacklist address.
     */
    function blockAddress(address addr, bool status) public onlyOwner {
        isBlocked[addr] = status;
        emit BlockUpdated(_msgSender(), addr, status);
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

    // INTERNAL FUNCTIONS

    /**
     * @notice Updated pre-public whitelist info.
     * @param _addresses whitelist addresses.
     * @param _categories category in DEX pre-public.
     */
    function _setPrePublicWhitelist(
        address[] memory _addresses,
        uint256[] memory _categories
    ) private {
        if (_addresses.length != _categories.length) {
            revert BICPrePublicWhitelist(_addresses, _categories);
        }
        for (uint256 i = 0; i < _addresses.length; i++) {
            _prePublicWhitelist[_addresses[i]] = _categories[i];
        }
        emit PrePublicWhitelistUpdated(_msgSender(), _addresses, _categories);
    }

    /**
     * @notice Updated pre-public round info.
     * @param _prePublicRound Pre-public round info.
     */
    function _setPrePublicRound(PrePublic memory _prePublicRound) private {
        prePublicRounds[_prePublicRound.category] = _prePublicRound;
        emit PrePublicRoundUpdated(_msgSender(), _prePublicRound.category);
    }

    /**
     * @notice Updated status of excluded address.
     * @param _excludedAddress excluded address
     * @param _status status of excluded address
     */
    function _setisExcluded(address _excludedAddress, bool _status) internal {
        isExcluded[_excludedAddress] = _status;
        emit ExcludedUpdated(_excludedAddress, _status);
    }

    /**
     * @notice Updated status of LP pool.
     * @param _pool pool address.
     * @param _status status of the pool.
     */
    function _setPool(address _pool, bool _status) internal {
        isPool[_pool] = _status;
        emit PoolUpdated(_msgSender(), _pool, _status);
    }

    /**
     * @notice Swap token for ETH.
     * @param _swapAmount swap tokens amount for ETH.
     */
    function _swapBack(uint256 _swapAmount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = IUniswapV2Router02(uniswapV2Router).WETH();
        accumulatedLF -= _swapAmount;
        _approve(address(this), uniswapV2Router, _swapAmount);

        IUniswapV2Router02(uniswapV2Router)
            .swapExactTokensForETHSupportingFeeOnTransferTokens(
                _swapAmount,
                0,
                path,
                address(this),
                block.timestamp
            );
    }

    /**
     * @notice Adding liquidity to the pool.
     * @param _liquidityToken0 token0 amount for LP.
     * @param _liquidityToken1 token1 amount for LP.
     */
    function _addLiquidity(
        uint256 _liquidityToken0,
        uint256 _liquidityToken1
    ) internal {
        accumulatedLF -= _liquidityToken0;
        _approve(address(this), uniswapV2Router, _liquidityToken0);
        IUniswapV2Router02(uniswapV2Router).addLiquidityETH{
            value: _liquidityToken1
        }(
            address(this),
            _liquidityToken0,
            0,
            0,
            liquidityTreasury,
            block.timestamp
        );
    }

    function _swapBackAndLiquify() internal {
        uint256 _initialToken1Balance;

        if (minSwapBackAmount == 0) {
            return;
        }

        uint256 liquidityTokens = minSwapBackAmount.div(2);
        uint256 amounTokensToSwap = minSwapBackAmount.sub(liquidityTokens);

        _initialToken1Balance = address(this).balance;

        _swapBack(amounTokensToSwap);

        uint256 _liquidityToken1;

        _liquidityToken1 = address(this).balance.sub(_initialToken1Balance);

        if (liquidityTokens > 0 && _liquidityToken1 > 0) {
            _addLiquidity(liquidityTokens, _liquidityToken1);
            emit SwapBackAndLiquify(liquidityTokens, _liquidityToken1);
        }
    }

    /**
     * @notice Override transfer to include liquidity fee logic.
     * @dev Event already defined and emitted in ERC20.sol
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        // Early returns for basic validations
        if (amount == 0) {
            super._update(from, to, 0);
            return;
        }

        // Skip additional checks if sender or receiver is excluded
        if (_isException(from, to)) {
            super._update(from, to, amount);
            return;
        }

        _validateBeforeTransfer(from);

        // Handle pre-public sale restrictions
        if (_prePublic && isPool[from]) {
            _validatePrePublicTransfer(to, amount);
        }

        // Process liquidity fee if applicable
        uint256 finalAmount = _processLiquidityFee(from, to, amount);

        super._update(from, to, finalAmount);
    }

    /**
     * @notice Validates basic transfer conditions
     * @dev Checks if transfer is paused and if sender is blocked
     * @param from Address attempting to send tokens
     */
    function _validateBeforeTransfer(address from) internal view {
        if (paused() || isBlocked[from]) {
            revert BICValidateBeforeTransfer(from);
        }
    }

    /**
     * @notice Checks if address is excluded from transfer rules
     * @param from Sender address
     * @param to Receiver address
     * @return bool True if excluded from rules
     */
    function _isException(
        address from,
        address to
    ) internal view returns (bool) {
        return isExcluded[from] || isExcluded[to] || _swapping;
    }

    /**
     * @notice Validate pre-public sale transfer restrictions
     * @dev Validates whitelist, round timing, cooldown and max buy amount
     * @param to Receiver address
     * @param amount Amount being transferred
     */
    function _validatePrePublicTransfer(address to, uint256 amount) internal {
        uint256 category = _prePublicWhitelist[to];
        if (category == 0) {
            revert BICInvalidCategory(to, category);
        }

        PrePublic memory round = prePublicRounds[category];
        if (!_isActivePrePublicRound(round)) {
            revert BICNotActiveRound(to, category);
        }
        if (!_isValidCooldown(to, round.coolDown)) {
            revert BICWaitForCoolDown(to, _coolDown[to] + round.coolDown);
        }
        if (amount > round.maxAmountPerBuy) {
            revert BICMaxAmountPerBuy(to, round.maxAmountPerBuy);
        }

        _coolDown[to] = block.timestamp;
    }

    /**
     * @notice Checks if a pre-public round is currently active
     * @dev Validates round start and end times against current block timestamp
     * @param round PrePublic round data
     * @return bool True if round is active
     */
    function _isActivePrePublicRound(
        PrePublic memory round
    ) internal view returns (bool) {
        return
            round.startTime <= block.timestamp &&
            round.endTime >= block.timestamp;
    }

    /**
     * @notice Validates cooldown period for pre-public purchases
     * @dev Ensures sufficient time has passed since last purchase
     * @param to Buyer address
     * @param coolDown Required cooldown period
     * @return bool True if cooldown period has passed
     */
    function _isValidCooldown(
        address to,
        uint256 coolDown
    ) internal view returns (bool) {
        return
            _coolDown[to] == 0 ||
            _coolDown[to] + coolDown <= block.timestamp;
    }

    /**
     * @notice Processes liquidity fee for transfers
     * @dev Handles swap back to ETH and liquidity addition if conditions are met
     * @param from Sender address
     * @param to Receiver address
     * @param amount Transfer amount
     * @return uint256 Final transfer amount after fees
     */
    function _processLiquidityFee(
        address from,
        address to,
        uint256 amount
    ) internal returns (uint256) {
        if (minLF == 0) {
            return amount;
        }

        // Handle swap back and liquify if needed
        if (_shouldSwapBack(from)) {
            _swapping = true;
            _swapBackAndLiquify();
            _swapping = false;
        }

        // Calculate and process liquidity fee
        uint256 liquidityFee = _calculateLiquidityFee(from, to, amount);
        if (liquidityFee > 0) {
            accumulatedLF += liquidityFee;
            super._update(from, address(this), liquidityFee);
            return amount - liquidityFee;
        }

        return amount;
    }

    /**
     * @notice Checks if conditions are met for swap back operation
     * @dev Validates accumulated fees and swap settings
     * @param from Source address of transfer
     * @return bool True if swap back should be executed
     */
    function _shouldSwapBack(address from) internal view returns (bool) {
        return
            accumulatedLF >= minSwapBackAmount &&
            swapBackEnabled &&
            from != uniswapV2Pair &&
            !_swapping;
    }

    /**
     * @notice Calculates liquidity fee for a transfer
     * @dev Applies fee based on transfer direction and settings
     * @param from Sender address
     * @param to Receiver address
     * @param amount Transfer amount
     * @return uint256 Calculated fee amount
     */
    function _calculateLiquidityFee(
        address from,
        address to,
        uint256 amount
    ) internal view returns (uint256) {
        if (isExcluded[from] || isExcluded[to] || _swapping) {
            return 0;
        }

        if (isPool[to] && minLF > 0) {
            return amount.mul(getCurrentLF()).div(10000);
        }

        return 0;
    }

    receive() external payable {}
}
