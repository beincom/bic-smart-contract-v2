// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IUniswapV2Router} from "../../src/interfaces/IUniswapV2Router.sol";
import {IUniswapV2Factory} from "../../src/interfaces/IUniswapV2Factory.sol";
import {SafeMath} from "../../src/utils/math/SafeMath.sol";
import {BICStorage} from "../storage/BICStorageV2.sol";
import {TokenSingletonPaymaster} from "../../src/base/TokenSingletonPaymaster.sol";

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BicTokenPaymasterV2 is
    TokenSingletonPaymaster,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeMath for uint256;
    using BICStorage for BICStorage.Data;

    // Get storage
    function _storage()
        internal
        pure
        virtual
        returns (BICStorage.Data storage $)
    {
        return BICStorage._getStorageLocation();
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

    /// @dev Emitted when changing max allocation per a wallet
    event MaxAllocationUpdated(address updater, uint256 newMaxAllocation);

    /// @dev Emitted when changing uinswap V2 pair
    event UniswapV2PairUpdated(
        address updater,
        address pair,
        address tokenPair
    );

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

    /// @dev Emitted when changing upgrade controller
    event UpgradeControllerUpdated(address updater, address controller);

    /// @dev Emitted when changing pre-public controller
    event PrePublicControllerUpdated(address updater, address controller);

    /// @dev Emitted when changing liquidity fee controller
    event LFControllerUpdated(address updater, address controller);

    /// @dev Emitted when changing max allocation controller
    event MaxAllocationControllerUpdated(address updater, address controller);

    /// @dev Emitted when changing treasury controller
    event TreasuryControllerUpdated(address updater, address controller);

    /// @dev Emitted when renouncing upgrade feature
    event RenounceUpgrade(address controller);

    /// @dev Emitted when renouncing pre-public feature
    event RenouncePrePublic(address controller);

    /// @dev Emitted when renouncing liquidity fee feature
    event RenounceLF(address controller);

    /// @dev Emitted when renouncing max allocation feature
    event RenounceMaxAllocation(address controller);

    /// @dev Emitted when renouncing treasury
    event RenounceTreasury(address controller);

    // MODIFIERS
    modifier onlyUpgradeController() {
        BICStorage.Data storage $ = _storage();
        require(
            _msgSender() == $._upgradeController,
            "B: only upgrade controller"
        );
        _;
    }

    modifier onlyPrePublicController() {
        BICStorage.Data storage $ = _storage();
        require(
            _msgSender() == $._prePublicController,
            "B: only pre-public controller"
        );
        _;
    }

    modifier onlyLFController() {
        BICStorage.Data storage $ = _storage();
        require(_msgSender() == $._LFController, "B: only LF controller");
        _;
    }

    modifier onlyMaxAllocationController() {
        BICStorage.Data storage $ = _storage();
        require(
            _msgSender() == $._maxAllocationController,
            "B: only max allocation controller"
        );
        _;
    }

    modifier onlyTreasuryController() {
        BICStorage.Data storage $ = _storage();
        require(
            _msgSender() == $._treasuryController,
            "B: only treasury controller"
        );
        _;
    }

    // CONSTRUCTOR & INITIALIZER
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        address superController
    ) public initializer {
        __ERC20_init(name, symbol);
        __Pausable_init();

        BICStorage.Data storage $ = _storage();

        uint256 _totalSupply = 5000000000 * 1e18;
        _mint(superController, _totalSupply);

        $._upgradeController = superController;
        $._prePublicController = superController;
        $._LFController = superController;
        $._maxAllocationController = superController;
        $._treasuryController = superController;

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
        $._maxAllocation = _totalSupply.mul(100).div(10000);
        $._enabledMaxAllocation = true;

        $._uniswapV2Router = IUniswapV2Router(
            0x920b806E40A00E02E7D2b94fFc89860fDaEd3640
        );
        $._uniswapV2Pair = IUniswapV2Factory($._uniswapV2Router.factory())
            .createPair(address(this), $._uniswapV2Router.WETH());
        $._tokenInPair = $._uniswapV2Router.WETH();
        _setPool($._uniswapV2Pair, true);
    }

    // VIEW FUNCTIONS
    /**
     * @notice Get whitelist category.
     * @param user user address.
     */
    function getWhitelistCategory(address user) public view returns (uint256) {
        BICStorage.Data storage $ = _storage();
        return $._prePublicWhitelist[user];
    }

    /**
     * @notice Get current liquidity fee
     * @return current liquidity fee
     */
    function getCurrentLF() public view returns (uint256) {
        BICStorage.Data storage $ = _storage();

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
     * @notice Updated upgrade controller.
     * @param controller controller address.
     */
    function setUpgradeController(
        address controller
    ) public onlyUpgradeController {
        BICStorage.Data storage $ = _storage();
        $._upgradeController = controller;
        emit UpgradeControllerUpdated(_msgSender(), controller);
    }

    /**
     * @notice Updated pre-public controller.
     * @param controller controller address.
     */
    function setPrePublicController(
        address controller
    ) public onlyPrePublicController {
        BICStorage.Data storage $ = _storage();
        $._prePublicController = controller;
        emit PrePublicControllerUpdated(_msgSender(), controller);
    }

    /**
     * @notice Updated liquidity fee controller.
     * @param controller controller address.
     */
    function setLFController(address controller) public onlyLFController {
        BICStorage.Data storage $ = _storage();
        $._LFController = controller;
        emit LFControllerUpdated(_msgSender(), controller);
    }

    /**
     * @notice Updated max allocation controller.
     * @param controller controller address.
     */
    function setMaxAllocationController(
        address controller
    ) public onlyMaxAllocationController {
        BICStorage.Data storage $ = _storage();
        $._maxAllocationController = controller;
        emit MaxAllocationControllerUpdated(_msgSender(), controller);
    }

    /**
     * @notice Updated treasury controller.
     * @param controller controller address.
     */
    function setTreasuryController(
        address controller
    ) public onlyTreasuryController {
        BICStorage.Data storage $ = _storage();
        $._treasuryController = controller;
        emit TreasuryControllerUpdated(_msgSender(), controller);
    }

    /**
     * @notice Renounce upgrade feature.
     */
    function renounceUpgrade() public onlyUpgradeController {
        BICStorage.Data storage $ = _storage();
        $._upgradeController = address(0);
        emit RenounceUpgrade(_msgSender());
    }

    /**
     * @notice Renounce max allocation feature.
     */
    function renounceMaxAllocation() public onlyMaxAllocationController {
        BICStorage.Data storage $ = _storage();
        $._enabledMaxAllocation = false;
        $._maxAllocation = totalSupply();
        $._maxAllocationController = address(0);
        emit RenounceMaxAllocation(_msgSender());
    }

    /**
     * @notice Renounce liquidity fee feature.
     */
    function renounceLF() public onlyLFController {
        BICStorage.Data storage $ = _storage();
        $._minLF = 0;
        $._maxLF = 0;
        $._LFController = address(0);
        emit RenounceLF(_msgSender());
    }

    /**
     * @notice Renounce pre-public feature.
     */
    function renouncePrePublic() public onlyPrePublicController {
        BICStorage.Data storage $ = _storage();
        $._prePublic = false;
        $._prePublicController = address(0);
        emit RenouncePrePublic(_msgSender());
    }

    /**
     * @notice Renounce treasury.
     */
    function renounceTreasury() public onlyTreasuryController {
        BICStorage.Data storage $ = _storage();
        $._treasuryController = address(0);
        emit RenounceTreasury(_msgSender());
    }

    // PRE-PUBLIC MANAGEMENT FUNCTIONS
    /**
     * @notice Updated pre-public status.
     * @param status pre-public status.
     */
    function setPrePublic(bool status) external onlyPrePublicController {
        BICStorage.Data storage $ = _storage();
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
    ) external onlyPrePublicController {
        _setPrePublicWhitelist(addresses, categories);
    }

    /**
     * @notice Updated pre-public round info.
     * @param prePublicRound Pre-public round info.
     */
    function setPrePublicRound(
        BICStorage.PrePublic memory prePublicRound
    ) external onlyPrePublicController {
        _setPrePublicRound(prePublicRound);
    }

    /**
     * @notice Update max allocation per a wallet.
     * @param newMaxAllocation new max allocation per a wallet.
     */
    function setMaxAllocation(
        uint256 newMaxAllocation
    ) external onlyMaxAllocationController {
        BICStorage.Data storage $ = _storage();
        $._maxAllocation = newMaxAllocation;
        emit MaxAllocationUpdated(_msgSender(), newMaxAllocation);
    }

    /**
     * @notice Updated pre-public whitelist info.
     * @param _addresses whitelist addresses.
     * @param _categories category in DEX pre-public.
     */
    function _setPrePublicWhitelist(
        address[] memory _addresses,
        uint256[] memory _categories
    ) private {
        BICStorage.Data storage $ = _storage();
        require(
            _addresses.length == _categories.length,
            "B: Mismatched length"
        );
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
        BICStorage.PrePublic memory _prePublicRound
    ) private {
        BICStorage.Data storage $ = _storage();
        $._prePublicRounds[_prePublicRound.category] = _prePublicRound;
        emit PrePublicRoundUpdated(_msgSender(), _prePublicRound.category);
    }

    // LIQUIDITY FEE MANAGEMENT FUNCTIONS
    /**
     * @notice Updated uniswap V2 pair.
     * @param pair uniswap V2 pair address.
     * @param tokenPair token in uniswap V2 pair.
     */
    function setUniswapV2Pair(
        address pair,
        address tokenPair
    ) external onlyLFController {
        BICStorage.Data storage $ = _storage();
        $._uniswapV2Pair = pair;
        $._tokenInPair = tokenPair;
        emit UniswapV2PairUpdated(_msgSender(), pair, tokenPair);
    }

    /**
     * @notice Update liquidity fee.
     * @param max max liquidity fee basic points.
     * @param min min liquidity fee basic points.
     */
    function setLiquidityFee(
        uint256 min,
        uint256 max
    ) external onlyLFController {
        require(min >= 0 && min <= max && max <= 5000, "B: invalid values");
        BICStorage.Data storage $ = _storage();
        $._minLF = min;
        $._maxLF = max;
        emit LiquidityFeeUpdated(_msgSender(), min, max);
    }

    /**
     * @notice Update liquidity fee reduction
     * @param _LFReduction liquidity fee reduction percent
     */
    function setLFReduction(uint256 _LFReduction) external onlyLFController {
        require(_LFReduction > 0, "B: 0 LF reduction");
        BICStorage.Data storage $ = _storage();
        $._LFReduction = _LFReduction;
        emit LFReductionUpdated(_msgSender(), _LFReduction);
    }

    /**
     * @notice Update liquidity fee period
     * @param _LFPeriod liquidity fee period
     */
    function setLFPeriod(uint256 _LFPeriod) external onlyLFController {
        require(_LFPeriod > 0, "B: 0 LF period");
        BICStorage.Data storage $ = _storage();
        $._LFPeriod = _LFPeriod;
        emit LFPeriodUpdated(_msgSender(), _LFPeriod);
    }

    // SWAP BACK MANAGEMENT FUNCTIONS
    /**
     * @notice Update swap back enabled status.
     * @param status swap back enabled status.
     */
    function setSwapBackEnabled(bool status) external onlyLFController {
        BICStorage.Data storage $ = _storage();
        $._swapBackEnabled = status;
        emit SwapBackEnabledUpdated(_msgSender(), status);
    }

    /**
     * @notice Update min swap back amount.
     * @param amount min swap back amount.
     */
    function setMinSwapBackAmount(uint256 amount) external onlyLFController {
        BICStorage.Data storage $ = _storage();
        $._minSwapBackAmount = amount;
        emit MinSwapBackAmountUpdated(_msgSender(), amount);
    }

    /**
     * @notice Update liquidity fee start time
     * @param _newLFStartTime new liquidity fee start time
     */
    function setLFStartTime(uint256 _newLFStartTime) external onlyLFController {
        require(_newLFStartTime > block.timestamp, "B: invalid start time");
        BICStorage.Data storage $ = _storage();
        $._LFStartTime = _newLFStartTime;
        emit LFStartTimeUpdated(_newLFStartTime);
    }

    /**
     * @notice Update enabled liquidity fee reduction
     * @param status enabled liquidity fee status
     */
    function setIsEnabledLFReduction(bool status) external onlyLFController {
        BICStorage.Data storage $ = _storage();
        $._isEnabledLFReduction = status;
        emit isEnabledLFReductionUpdated(_msgSender(), status);
    }

    // POOL MANAGEMENT FUNCTIONS
    /**
     * @notice Updated status of LP pool.
     * @param pool pool address.
     * @param status status of the pool.
     */
    function setPool(address pool, bool status) external onlyLFController {
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
    ) external onlyLFController {
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
    ) external onlyTreasuryController {
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
    ) external onlyTreasuryController {
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
        address to
    ) public onlyTreasuryController {
        bool success;
        if (token == address(0)) {
            (success, ) = address(to).call{value: address(this).balance}("");
        } else {
            uint256 amount = IERC20(token).balanceOf(address(this));
            require(amount > 0, "B: 0 amount token");
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
    ) public onlyTreasuryController {
        BICStorage.Data storage $ = _storage();
        $._isBlocked[addr] = status;
        emit BlockUpdated(_msgSender(), addr, status);
    }

    /**
     * @notice Pause transfers using this token. For emergency use.
     * @dev Event already defined and emitted in Pausable.sol
     */
    function pause() public onlyTreasuryController {
        _pause();
    }

    /**
     * @notice Unpause transfers using this token.
     * @dev Event already defined and emitted in Pausable.sol
     */
    function unpause() public onlyTreasuryController {
        _unpause();
    }

    // INTERNAL FUNCTIONS
    /**
     * @notice Updated status of excluded address.
     * @param _excludedAddress excluded address
     * @param _status status of excluded address
     */
    function _setIsExcluded(address _excludedAddress, bool _status) internal {
        BICStorage.Data storage $ = _storage();
        $._isExcluded[_excludedAddress] = _status;
        emit ExcludedUpdated(_excludedAddress, _status);
    }

    /**
     * @notice Updated status of LP pool.
     * @param _pool pool address.
     * @param _status status of the pool.
     */
    function _setPool(address _pool, bool _status) internal {
        BICStorage.Data storage $ = _storage();
        $._isPool[_pool] = _status;
        emit PoolUpdated(_msgSender(), _pool, _status);
    }

    /**
     * @notice Swap token for ETH.
     * @param _swapAmount swap tokens amount for ETH.
     */
    function _swapBack(uint256 _swapAmount) internal {
        BICStorage.Data storage $ = _storage();
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = $._tokenInPair;

        _approve(address(this), address($._uniswapV2Router), _swapAmount);

        if ($._tokenInPair == $._uniswapV2Router.WETH()) {
            $
                ._uniswapV2Router
                .swapExactTokensForETHSupportingFeeOnTransferTokens(
                    _swapAmount,
                    0,
                    path,
                    address(this),
                    block.timestamp
                );
        } else {
            $
                ._uniswapV2Router
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    _swapAmount,
                    0,
                    path,
                    address(this),
                    block.timestamp
                );
        }
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
        BICStorage.Data storage $ = _storage();
        _approve(address(this), address($._uniswapV2Router), _liquidityToken0);
        if ($._tokenInPair == $._uniswapV2Router.WETH()) {
            $._uniswapV2Router.addLiquidityETH{value: _liquidityToken1}(
                address(this),
                _liquidityToken0,
                0,
                0,
                address(0),
                block.timestamp
            );
        } else {
            IERC20($._tokenInPair).approve(
                address($._uniswapV2Router),
                _liquidityToken1
            );
            $._uniswapV2Router.addLiquidity(
                address(this),
                $._tokenInPair,
                _liquidityToken0,
                _liquidityToken1,
                0,
                0,
                address(0),
                block.timestamp
            );
        }
    }

    function _swapBackAndLiquify() internal {
        BICStorage.Data storage $ = _storage();
        uint256 _initialToken1Balance;

        if ($._minSwapBackAmount == 0) {
            return;
        }

        uint256 liquidityTokens = $._minSwapBackAmount.div(2);
        uint256 amounTokensToSwap = $._minSwapBackAmount.sub(liquidityTokens);

        if ($._tokenInPair == $._uniswapV2Router.WETH()) {
            _initialToken1Balance = address(this).balance;
        } else {
            _initialToken1Balance = IERC20($._tokenInPair).balanceOf(
                address(this)
            );
        }

        _swapBack(amounTokensToSwap);

        uint256 _liquidityToken1;

        if ($._tokenInPair == $._uniswapV2Router.WETH()) {
            _liquidityToken1 = address(this).balance.sub(_initialToken1Balance);
        } else {
            _liquidityToken1 = IERC20($._tokenInPair)
                .balanceOf(address(this))
                .sub(_initialToken1Balance);
        }

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
        BICStorage.Data storage $ = _storage();

        if (!$._isExcluded[from]) {
            require(!paused(), "B: paused transfer");
        }
        require(!$._isBlocked[from], "B: blocked from address");

        if (amount == 0) {
            super._update(from, to, 0);
            return;
        }

        // Guard max allocation
        if (
            !$._isExcluded[from] &&
            !$._isExcluded[to] &&
            to != address(0) &&
            to != address(0xdead) &&
            !$._swapping
        ) {
            // Pre-public round
            if ($._prePublic) {
                uint256 _category = $._prePublicWhitelist[to];
                require(_category != 0, "B: only pre-public whitelist");
                BICStorage.PrePublic memory _round = $._prePublicRounds[
                    _category
                ];
                require(
                    _round.startTime <= block.timestamp &&
                        _round.endTime >= block.timestamp,
                    "B: round not active"
                );
                require(
                    $._coolDown[to] == 0 ||
                        $._coolDown[to] + _round.coolDown <= block.timestamp,
                    "B: wait for cool down"
                );
                require(
                    amount <= _round.maxAmountPerBuy,
                    "B: exceed max amount per buy in pre-public"
                );
                $._coolDown[to] = block.timestamp;
            }

            // guard on buy
            if ($._enabledMaxAllocation && $._isPool[from]) {
                require(
                    balanceOf(to) + amount <= $._maxAllocation,
                    "B: exceed max allocation"
                );
            }
        }

        if ($._minLF > 0) {
            // swap back and liquify
            uint256 contractTokenBalance = balanceOf(address(this));
            bool canSwapBackAndLiquify = contractTokenBalance >=
                $._minSwapBackAmount;
            if (
                canSwapBackAndLiquify &&
                $._swapBackEnabled &&
                from != $._uniswapV2Pair &&
                !$._swapping
            ) {
                $._swapping = true;
                _swapBackAndLiquify();
                $._swapping = false;
            }

            // Extract liquidity fee
            bool _isTakenFee = !$._swapping;

            if ($._isExcluded[from] || $._isExcluded[to]) {
                _isTakenFee = false;
            }

            uint256 _LF = 0;

            if (_isTakenFee) {
                // charge liquidity on sell
                if ($._isPool[to] && $._minLF > 0) {
                    _LF = amount.mul(getCurrentLF()).div(10000);
                }
            }

            if (_LF > 0) {
                super._transfer(from, address(this), _LF);
            }

            amount -= _LF;
        }

        super._transfer(from, to, amount);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(
        address
    ) internal view virtual override(UUPSUpgradeable) onlyUpgradeController {}

    receive() external payable {}

    // function setNewValue(uint256 _value) external {
    //     _storage()._newValue = _value;
    // }

    // function getNewValue() external view returns (uint256) {
    //     return _storage()._newValue;
    // }

    // function setNewAddress(address _addr) external {
    //     _storage()._newAddress = _addr;
    // }

    // function getNewAddress() external view returns (address) {
    //     return _storage()._newAddress;
    // }
}
