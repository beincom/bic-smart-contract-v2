// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {SafeMath} from "./utils/math/SafeMath.sol";
import {B139Storage} from "./storage/B139Storage.sol";
import {TokenSingletonPaymaster} from "./base/TokenSingletonPaymaster.sol";

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BICErrors} from "./interfaces/BICErrors.sol";
contract B139 is
    TokenSingletonPaymaster,
    PausableUpgradeable,
    UUPSUpgradeable,
    BICErrors
{
    using SafeMath for uint256;
    using B139Storage for B139Storage.Data;

    // Get storage
    function _storage()
        internal
        pure
        virtual
        returns (B139Storage.Data storage $)
    {
        return B139Storage._getStorageLocation();
    }

    // EVENTS
    /// @dev Emitted when changing a pre-public status
    event PrePublicStatusUpdated(address updater, bool status);

    /// @dev Emitted when changing a pre-public whitelist
    event PrePublicWhitelistUpdated(
        address updater,
        address[] addresses,
        uint256[] categories
    );

    /// @dev Emitted when changing a specific pre-public round info
    event PrePublicRoundUpdated(address updater, uint256 category);

    /// @dev Emitted when swap back and liquify
    event SwapBackAndLiquify(uint256 liquidityTokens, uint256 ETHForLiquidity);

    /// @dev Emitted when changing swap back enabled status
    event SwapBackEnabledUpdated(address updater, bool status);

    /// @dev Emitted when chaning min swap back amount
    event MinSwapBackAmountUpdated(address updater, uint256 amount);

    /// @dev Emitted when changing liquidity fee
    event LiquidityFeeUpdated(address updater, uint256 min, uint256 max);

    /// @dev Emitted when updating excluded address
    event ExcludedUpdated(address excludedAddress, bool status);

    /// @dev Emitted when updating LP pools
    event PoolUpdated(address updater, address pool, bool status);

    /// @dev Emitted when updating blacklist
    event BlockUpdated(address updater, address addr, bool status);

    /// @dev Emitted when liquidity fee interval step is upadted
    event LFReductionUpdated(address updater, uint256 _LFReduction);

    /// @dev Emitted when changing liquidity fee period
    event LFPeriodUpdated(address updater, uint256 LFPeriod);

    /// @dev Emitted when changing LF start time
    event LFStartTimeUpdated(uint256 _newLFStartTime);

    /// @dev Emitted when changing enabled liquidity fee reduction
    event isEnabledLFReductionUpdated(address updater, bool status);

    /// @dev Emitted when changing manager
    event ManagerUpdated(address updater, address newManager);

    /// @dev Emitted when changing operator
    event OperatorUpdated(address updater, address newOperator);

    /// @dev Emitted when renouncing manager
    event RenounceManager(address manager);

    /// @dev Emitted when renouncing operator
    event RenounceOperator(address operator);


    /// @dev Emitted when changing liquidity treasury
    event LiquidityTreasuryUpdated(address updater, address newLFTreasury);

    // MODIFIERS
    modifier onlyManager() {
        _isManager();
        _;
    }

    modifier onlyOperator() {
        _isOperator();
        _;
    }

    // CONSTRUCTOR & INITIALIZER
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _entryPoint,
        address superController,
        address[] memory _singers
    ) public initializer {
        __TokenSingletonPaymaster_init(_entryPoint, _singers);
        __ERC20_init("BTest", "BTEST");
        __Pausable_init();

        B139Storage.Data storage $ = _storage();

        uint256 _totalSupply = 888 * 1e27;
        _mint(superController, _totalSupply);

        $._manager = superController;
        $._operator = superController;

        $._liquidityTreasury = superController;

        $._maxLF = 1500;
        $._minLF = 300;
        $._LFReduction = 50;
        $._LFPeriod = 60 * 60 * 24 * 30; // 30 days
        $._isEnabledLFReduction = true;
        $._LFStartTime = block.timestamp;
        $._isExcluded[superController] = true;
        $._isExcluded[address(this)] = true;

        $._prePublic = true;

        $._swapBackEnabled = true;
        $._minSwapBackAmount = _totalSupply.div(10000);

        $._uniswapV2Router = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
        $._uniswapV2Pair = IUniswapV2Factory(
            IUniswapV2Router02($._uniswapV2Router).factory()
        ).createPair(
                address(this),
                IUniswapV2Router02($._uniswapV2Router).WETH()
            );
        _setPool($._uniswapV2Pair, true);

        transferOwnership(superController);
    }

    // VIEW FUNCTIONS
    /**
     * @notice Get accumulated LF
     */
    function getAccumulatedLF() public view returns (uint256) {
        B139Storage.Data storage $ = _storage();
        return $._accumulatedLF;
    }

    /**
     * @notice Get uniswap v2 pair
     */
    function getUniswapV2Pair() public view returns (address) {
        B139Storage.Data storage $ = _storage();
        return $._uniswapV2Pair;
    }

    /**
     * @notice Get pre-public round
     * @param category pre-public category
     */
    function getPrePublicRound(
        uint256 category
    ) public view returns (B139Storage.PrePublic memory) {
        B139Storage.Data storage $ = _storage();
        return $._prePublicRounds[category];
    }

    /**
     * @notice Get LF reduction */
    function LFReduction() public view returns (uint256) {
        B139Storage.Data storage $ = _storage();
        return $._LFReduction;
    }

    /**
     * @notice Get LF period
     */
    function LFPeriod() public view returns (uint256) {
        B139Storage.Data storage $ = _storage();
        return $._LFPeriod;
    }

    /**
     * @notice Get max LF
     */
    function maxLF() public view returns (uint256) {
        B139Storage.Data storage $ = _storage();
        return $._maxLF;
    }

    /**
     * @notice Get min LF
     */
    function minLF() public view returns (uint256) {
        B139Storage.Data storage $ = _storage();
        return $._minLF;
    }

    /**
     * @notice Get whitelist category.
     * @param user user address.
     */
    function getWhitelistCategory(address user) public view returns (uint256) {
        B139Storage.Data storage $ = _storage();
        return $._prePublicWhitelist[user];
    }

    /**
     * @notice Check if user is blocked
     * @param user user address
     */
    function isBlocked(address user) public view returns (bool) {
        B139Storage.Data storage $ = _storage();
        return $._isBlocked[user];
    }

    /**
     * @notice Get current liquidity fee
     * @return current liquidity fee
     */
    function getCurrentLF() public view returns (uint256) {
        B139Storage.Data storage $ = _storage();

        if (!$._isEnabledLFReduction) {
            return $._minLF;
        }

        uint256 totalReduction = block
            .timestamp
            .sub($._LFStartTime)
            .mul($._LFReduction)
            .div($._LFPeriod);

        if (totalReduction + $._minLF >= $._maxLF) {
            return $._minLF;
        } else {
            return $._maxLF.sub(totalReduction);
        }
    }

    // CONTROLLER MANAGEMENT FUNCTIONS
    /**
     * @notice Update manager.
     * @param manager manager address.
     */
    function setManager(
        address manager
    ) public onlyManager {
        B139Storage.Data storage $ = _storage();
        $._manager = manager;
        emit ManagerUpdated(_msgSender(), manager);
    }

    /**
     * @notice Update operator.
     * @param operator operator address.
     */
    function setOperator(
        address operator
    ) public onlyManager {
        B139Storage.Data storage $ = _storage();
        $._operator = operator;
        emit OperatorUpdated(_msgSender(), operator);
    }

    /**
     * @notice Renounce upgrade feature.
     */
    function renounceManager() public onlyManager {
        B139Storage.Data storage $ = _storage();
        $._manager = address(0);
        emit RenounceManager(_msgSender());
    }

    /**
     * @notice Renounce max allocation feature.
     */
    function renounceOperator() public onlyOperator {
        B139Storage.Data storage $ = _storage();
        $._operator = address(0);
        emit RenounceOperator(_msgSender());
    }

    // PRE-PUBLIC MANAGEMENT FUNCTIONS
    /**
     * @notice Updated pre-public status.
     * @param status pre-public status.
     */
    function setPrePublic(bool status) external onlyOperator {
        B139Storage.Data storage $ = _storage();
        $._prePublic = status;
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
    ) external onlyOperator {
        _setPrePublicWhitelist(addresses, categories);
    }

    /**
     * @notice Updated pre-public round info.
     * @param prePublicRound Pre-public round info.
     */
    function setPrePublicRound(
        B139Storage.PrePublic memory prePublicRound
    ) external onlyOperator {
        _setPrePublicRound(prePublicRound);
    }

    // LIQUIDITY FEE MANAGEMENT FUNCTIONS

    /**
     * @notice Update liquidity treasury.
     * @param newLFTreasury new liquidity treasury.
     */
    function setLiquidityTreasury(
        address newLFTreasury
    ) external onlyManager {
        B139Storage.Data storage $ = _storage();
        $._liquidityTreasury = newLFTreasury;
        emit LiquidityTreasuryUpdated(_msgSender(), newLFTreasury);
    }

    /**
     * @notice Update liquidity fee.
     * @param max max liquidity fee basic points.
     * @param min min liquidity fee basic points.
     */
    function setLiquidityFee(
        uint256 min,
        uint256 max
    ) external onlyOperator {
        require(min >= 0 && min <= max && max <= 5000, "B: invalid values");
        B139Storage.Data storage $ = _storage();
        $._minLF = min;
        $._maxLF = max;
        emit LiquidityFeeUpdated(_msgSender(), min, max);
    }

    /**
     * @notice Update liquidity fee reduction
     * @param _LFReduction liquidity fee reduction percent
     */
    function setLFReduction(uint256 _LFReduction) external onlyOperator {
        if (_LFReduction <= 0) {
            revert BICLFReduction(_LFReduction);
        }
        B139Storage.Data storage $ = _storage();
        $._LFReduction = _LFReduction;
        emit LFReductionUpdated(_msgSender(), _LFReduction);
    }

    /**
     * @notice Update liquidity fee period
     * @param _LFPeriod liquidity fee period
     */
    function setLFPeriod(uint256 _LFPeriod) external onlyOperator {
        if (_LFPeriod <= 0) {
            revert BICLFPeriod(_LFPeriod);
        }
        B139Storage.Data storage $ = _storage();
        $._LFPeriod = _LFPeriod;
        emit LFPeriodUpdated(_msgSender(), _LFPeriod);
    }

    // SWAP BACK MANAGEMENT FUNCTIONS
    /**
     * @notice Update swap back enabled status.
     * @param status swap back enabled status.
     */
    function setSwapBackEnabled(bool status) external onlyOperator {
        B139Storage.Data storage $ = _storage();
        $._swapBackEnabled = status;
        emit SwapBackEnabledUpdated(_msgSender(), status);
    }

    /**
     * @notice Update min swap back amount.
     * @param amount min swap back amount.
     */
    function setMinSwapBackAmount(uint256 amount) external onlyOperator {
        B139Storage.Data storage $ = _storage();
        $._minSwapBackAmount = amount;
        emit MinSwapBackAmountUpdated(_msgSender(), amount);
    }

    /**
     * @notice Update liquidity fee start time
     * @param newLFStartTime new liquidity fee start time
     */
    function setLFStartTime(uint256 newLFStartTime) external onlyOperator {
        if (newLFStartTime < block.timestamp) {
            revert BICLFStartTime(newLFStartTime);
        }
        B139Storage.Data storage $ = _storage();
        $._LFStartTime = newLFStartTime;
        emit LFStartTimeUpdated(newLFStartTime);
    }

    /**
     * @notice Update enabled liquidity fee reduction
     * @param status enabled liquidity fee status
     */
    function setIsEnabledLFReduction(bool status) external onlyOperator {
        B139Storage.Data storage $ = _storage();
        $._isEnabledLFReduction = status;
        emit isEnabledLFReductionUpdated(_msgSender(), status);
    }

    // POOL MANAGEMENT FUNCTIONS
    /**
     * @notice Updated status of LP pool.
     * @param pool pool address.
     * @param status status of the pool.
     */
    function setPool(address pool, bool status) external onlyOperator {
        _setPool(pool, status);
    }

    /**
     * @notice Updated status of LP pools.
     * @param pools pool addresses.
     * @param status status of the pool.
     */
    function bulkPool(
        address[] memory pools,
        bool status
    ) external onlyOperator {
        for (uint256 i = 0; i < pools.length; i++) {
            _setPool(pools[i], status);
        }
    }

    /**
     * @notice Updated status of excluded address.
     * @param excludedAddress excluded address
     * @param status status of excluded address
     */
    function setIsExcluded(
        address excludedAddress,
        bool status
    ) external onlyManager {
        _setIsExcluded(excludedAddress, status);
    }

    /**
     * @notice Updated status of excluded addresses.
     * @param excludedAddresses excluded addresses
     * @param status status of excluded address
     */
    function bulkExcluded(
        address[] memory excludedAddresses,
        bool status
    ) external onlyManager {
        for (uint256 i = 0; i < excludedAddresses.length; i++) {
            _setIsExcluded(excludedAddresses[i], status);
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
    ) public onlyManager {
        bool success;
        if (token == address(0)) {
            (success, ) = address(to).call{value: amount}("");
        } else {
            IERC20(token).transfer(to, amount);
        }
    }

    /**
     * @notice Block malicious address.
     * @param addr blacklist address.
     */
    function blockAddress(
        address addr,
        bool status
    ) public onlyManager {
        B139Storage.Data storage $ = _storage();
        $._isBlocked[addr] = status;
        emit BlockUpdated(_msgSender(), addr, status);
    }

    /**
     * @notice Pause transfers using this token. For emergency use.
     * @dev Event already defined and emitted in Pausable.sol
     */
    function pause() public onlyManager {
        _pause();
    }

    /**
     * @notice Unpause transfers using this token.
     * @dev Event already defined and emitted in Pausable.sol
     */
    function unpause() public onlyManager {
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
        B139Storage.Data storage $ = _storage();
        if (_addresses.length != _categories.length) {
            revert BICPrePublicWhitelist(_addresses, _categories);
        }
        for (uint256 i = 0; i < _addresses.length; i++) {
            $._prePublicWhitelist[_addresses[i]] = _categories[i];
        }
        emit PrePublicWhitelistUpdated(_msgSender(), _addresses, _categories);
    }

    /**
     * @notice Updated pre-public round info.
     * @param _prePublicRound Pre-public round info.
     */
    function _setPrePublicRound(
        B139Storage.PrePublic memory _prePublicRound
    ) private {
        B139Storage.Data storage $ = _storage();
        $._prePublicRounds[_prePublicRound.category] = _prePublicRound;
        emit PrePublicRoundUpdated(_msgSender(), _prePublicRound.category);
    }

    /**
     * @notice Updated status of excluded address.
     * @param _excludedAddress excluded address
     * @param _status status of excluded address
     */
    function _setIsExcluded(address _excludedAddress, bool _status) internal {
        B139Storage.Data storage $ = _storage();
        $._isExcluded[_excludedAddress] = _status;
        emit ExcludedUpdated(_excludedAddress, _status);
    }

    /**
     * @notice Updated status of LP pool.
     * @param _pool pool address.
     * @param _status status of the pool.
     */
    function _setPool(address _pool, bool _status) internal {
        B139Storage.Data storage $ = _storage();
        $._isPool[_pool] = _status;
        emit PoolUpdated(_msgSender(), _pool, _status);
    }

    /**
     * @notice Swap token for ETH.
     * @param _swapAmount swap tokens amount for ETH.
     */
    function _swapBack(uint256 _swapAmount) internal {
        B139Storage.Data storage $ = _storage();
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = IUniswapV2Router02($._uniswapV2Router).WETH();
        $._accumulatedLF -= _swapAmount;
        _approve(address(this), $._uniswapV2Router, _swapAmount);

        IUniswapV2Router02($._uniswapV2Router)
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
        B139Storage.Data storage $ = _storage();
        $._accumulatedLF -= _liquidityToken0;
        _approve(address(this), $._uniswapV2Router, _liquidityToken0);
        IUniswapV2Router02($._uniswapV2Router).addLiquidityETH{
            value: _liquidityToken1
        }(
            address(this),
            _liquidityToken0,
            0,
            0,
            $._liquidityTreasury,
            block.timestamp
        );
    }

    function _swapBackAndLiquify() internal {
        B139Storage.Data storage $ = _storage();
        uint256 _initialToken1Balance;

        if ($._minSwapBackAmount == 0) {
            return;
        }

        uint256 liquidityTokens = $._minSwapBackAmount.div(2);
        uint256 amounTokensToSwap = $._minSwapBackAmount.sub(liquidityTokens);

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
        B139Storage.Data storage $ = _storage();

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
        if ($._prePublic && $._isPool[from]) {
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
        B139Storage.Data storage $ = _storage();
        if (paused() || $._isBlocked[from]) {
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
        B139Storage.Data storage $ = _storage();
        return $._isExcluded[from] || $._isExcluded[to] || $._swapping;
    }

    /**
     * @notice Validate pre-public sale transfer restrictions
     * @dev Validates whitelist, round timing, cooldown and max buy amount
     * @param to Receiver address
     * @param amount Amount being transferred
     */
    function _validatePrePublicTransfer(address to, uint256 amount) internal {
        B139Storage.Data storage $ = _storage();
        uint256 category = $._prePublicWhitelist[to];
        if (category == 0) {
            revert BICInvalidCategory(to, category);
        }

        B139Storage.PrePublic memory round = $._prePublicRounds[category];
        if (!_isActivePrePublicRound(round)) {
            revert BICNotActiveRound(to, category);
        }
        if (!_isValidCooldown(to, round.coolDown)) {
            revert BICWaitForCoolDown(to, $._coolDown[to] + round.coolDown);
        }
        if (amount > round.maxAmountPerBuy) {
            revert BICMaxAmountPerBuy(to, round.maxAmountPerBuy);
        }

        $._coolDown[to] = block.timestamp;
    }

    /**
     * @notice Checks if a pre-public round is currently active
     * @dev Validates round start and end times against current block timestamp
     * @param round PrePublic round data
     * @return bool True if round is active
     */
    function _isActivePrePublicRound(
        B139Storage.PrePublic memory round
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
        B139Storage.Data storage $ = _storage();
        return
            $._coolDown[to] == 0 ||
            $._coolDown[to] + coolDown <= block.timestamp;
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
        B139Storage.Data storage $ = _storage();

        if ($._minLF == 0) {
            return amount;
        }

        // Handle swap back and liquify if needed
        if (_shouldSwapBack(from)) {
            $._swapping = true;
            _swapBackAndLiquify();
            $._swapping = false;
        }

        // Calculate and process liquidity fee
        uint256 liquidityFee = _calculateLiquidityFee(from, to, amount);
        if (liquidityFee > 0) {
            $._accumulatedLF += liquidityFee;
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
        B139Storage.Data storage $ = _storage();
        return
            $._accumulatedLF >= $._minSwapBackAmount &&
            $._swapBackEnabled &&
            from != $._uniswapV2Pair &&
            !$._swapping;
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
        B139Storage.Data storage $ = _storage();

        if ($._isExcluded[from] || $._isExcluded[to] || $._swapping) {
            return 0;
        }

        if ($._isPool[to] && $._minLF > 0) {
            return amount.mul(getCurrentLF()).div(10000);
        }

        return 0;
    }

    /// @dev Check if the current call is manager
    function _isManager() private view {
        B139Storage.Data storage $ = _storage();
        address caller = _msgSender();
        if (caller != $._manager) {
            revert BICUnauthorized(caller, $._manager);
        }
    }

    /// @dev Check if the current call is operator
    function _isOperator() private view {
        B139Storage.Data storage $ = _storage();
        address caller = _msgSender();
        if (caller != $._operator) {
            revert BICUnauthorized(caller, $._operator);
        }
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(
        address
    ) internal virtual override(UUPSUpgradeable) onlyManager {}

    receive() external payable {}
}
