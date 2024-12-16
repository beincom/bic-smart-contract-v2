// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import {IUniswapV2Router} from "../interfaces/IUniswapV2Router.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";
import {SafeMath} from "../utils/math/SafeMath.sol";
import {TokenSingletonPaymaster} from "../base/TokenSingletonPaymaster.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BICTokenPaymaster is TokenSingletonPaymaster, PausableUpgradeable, UUPSUpgradeable {
    using SafeMath for uint256;

    /// implementation slot
    bytes32 public constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;


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
    IUniswapV2Router public uniswapV2Router;

    /// Uniswap V2 pair
    address public uniswapV2Pair;

    /// token in uniswap V2 pair
    address public tokenInPair;

    /// Swap back and liquify threshold
    uint256 private _minSwapBackAmount;

    /// Swap back enabled
    bool private _swapBackEnabled;

    /// Guard swapping
    bool private _swapping;


    /// Max allocation per a wallet
    uint256 public maxAllocation;

    /// Max allocation enabled
    bool public enabledMaxAllocation;


    /// Role based access control
    address public upgradeController;
    address public prePublicController;
    address public LFController;
    address public maxAllocationController;
    address public treasuryController;

    
    /// Whitelist for pre-public in DEX
    mapping(address => uint256) private _prePublicWhitelist;

    /// Cooldown in Pre-public round in DEX
    mapping(address => uint256) private _coolDown;

    /// Pre-public round in DEX
    mapping(uint256 => PrePublic) public prePublicRounds;

    /// excluded from liquidity fee
    mapping(address => bool) private _isExcluded;

    /// whitelist pools to charge liquidity fee on
    mapping(address => bool) private _isPool;

    /// The blocked users
    mapping (address => bool) public isBlocked;


    /// @dev Emitted when changing a pre-public status
    event PrePublicStatusUpdated(address updater, bool status);

    /// @dev Emitted when changing a pre-public whitelist
    event PrePublicWhitelistUpdated(address updater, address[] addresses, uint256[] categories);

    /// @dev Emitted when changing a specific pre-public round info
    event PrePublicRoundUpdated(address updater, uint256 category);

    /// @dev Emitted when changing max allocation per a wallet
    event MaxAllocationUpdated(address updater, uint256 newMaxAllocation);

    /// @dev Emitted when changing uinswap V2 pair
    event UniswapV2PairUpdated(address updater, address pair, address tokenPair);

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

    /// Only upgrade controller role
    modifier onlyUpgradeController {
        require(_msgSender() == upgradeController, "B: only upgrade ontroller");
        _;
    }

    /// Only pre-public controller role
    modifier onlyPrePublicController {
        require(_msgSender() == prePublicController, "B: only pre-public ontroller");
        _;
    }

    /// Only liquidity fee controller role
    modifier onlyLFController {
        require(_msgSender() == LFController, "B: only LF ontroller");
        _;
    }

    /// Only max allocation controller role
    modifier onlyMaxAllocationController {
        require(_msgSender() == maxAllocationController, "B: only max allocation ontroller");
        _;
    }

    /// Only max allocation controller role
    modifier onlyTreasuryController {
        require(_msgSender() == treasuryController, "B: only treasury ontroller");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        address superController,
        address entryPoint,
        address[] memory signers
    ) public initializer {
        __TokenSingletonPaymaster_init(entryPoint, signers);
        __ERC20_init(name, symbol);
        __ERC20Votes_init();
        __Pausable_init();

        uint256 _totalSupply = 888 * 1e27;
        _mint(superController, _totalSupply);

        upgradeController = superController;
        prePublicController = superController;
        LFController = superController;
        maxAllocationController = superController;
        treasuryController = superController;

        maxLF = 1500;
        minLF = 300;
        LFReduction = 50;
        LFPeriod = 60 * 60 * 24 * 30; // 30 days
        isEnabledLFReduction = true;
        LFStartTime = block.timestamp;
        _isExcluded[superController] = true;
        _isExcluded[address(this)] = true;

        _prePublic = true;

        _swapBackEnabled = true;
        _minSwapBackAmount = _totalSupply.div(10000);
        maxAllocation = _totalSupply.mul(100).div(10000);
        enabledMaxAllocation = true;

        uniswapV2Router = IUniswapV2Router(0x920b806E40A00E02E7D2b94fFc89860fDaEd3640);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        tokenInPair = uniswapV2Router.WETH();
        _setPool(uniswapV2Pair, true);
    }

    /// @notice Returns the implementation of the ERC1967 proxy.
    ///
    /// @return $ The address of implementation contract.
    function implementation() public view returns (address $) {
        assembly {
            $ := sload(IMPLEMENTATION_SLOT)
        }
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
        if(!isEnabledLFReduction) {
            return minLF;
        }

        uint256 totalReduction = block.timestamp.sub(LFStartTime).mul(LFReduction).div(LFPeriod);
        
        if (totalReduction + minLF >= maxLF ) {
            return minLF; 
        } else {
            return maxLF.sub(totalReduction);
        }
    }

    receive() external payable {}

    /**
     * @notice Updated upgrade controller.
     * @param controller controller address.
     */
    function setUpgradeController(address controller) public onlyUpgradeController {
        upgradeController = controller;
        emit UpgradeControllerUpdated(_msgSender(), controller);
    }

    /**
     * @notice Updated pre-public controller.
     * @param controller controller address.
     */
    function setPrePublicController(address controller) public onlyPrePublicController {
        prePublicController = controller;
        emit PrePublicControllerUpdated(_msgSender(), controller);
    }

    /**
     * @notice Updated liquidity fee controller.
     * @param controller controller address.
     */
    function setLFController(address controller) public onlyLFController {
        LFController = controller;
        emit LFControllerUpdated(_msgSender(), controller);
    }

    /**
     * @notice Updated max allocation controller.
     * @param controller controller address.
     */
    function setMaxAllocationController(address controller) public onlyMaxAllocationController {
        maxAllocationController = controller;
        emit MaxAllocationControllerUpdated(_msgSender(), controller);
    }

    /**
     * @notice Updated treasury controller.
     * @param controller controller address.
     */
    function setTreasuryController(address controller) public onlyTreasuryController {
        treasuryController = controller;
        emit TreasuryControllerUpdated(_msgSender(), controller);
    }

    /**
     * @notice Renounce upgrade feature.
     */
    function renounceUpgrade() public onlyUpgradeController {
        upgradeController = address(0);
        emit RenounceUpgrade(_msgSender());
    }

    /**
     * @notice Renounce max allocation feature.
     */
    function renounceMaxAllocation() public onlyMaxAllocationController {
        enabledMaxAllocation = false;
        maxAllocation = totalSupply();
        maxAllocationController = address(0);
        emit RenounceMaxAllocation(_msgSender());
    }

    /**
     * @notice Renounce liquidity fee feature.
     */
    function renounceLF() public onlyLFController {
        minLF = 0;
        maxLF = 0;
        LFController = address(0);
        emit RenounceLF(_msgSender());
    }

    /**
     * @notice Renounce pre-public feature.
     */
    function renouncePrePublic() public onlyPrePublicController {
        _prePublic = false;
        prePublicController = address(0);
        emit RenouncePrePublic(_msgSender());
    }

    /**
     * @notice Renounce treasury.
     */
    function renounceTreasury() public onlyTreasuryController() {
        treasuryController = address(0);
        emit RenounceTreasury(_msgSender());
    }

    /**
     * @notice Updated pre-public status.
     * @param status pre-public status.
     */
    function setPrePublic(bool status) external onlyPrePublicController {
        _prePublic = status;
        emit PrePublicStatusUpdated(_msgSender(), status);
    }

    /**
     * @notice Updated pre-public whitelist info.
     * @param addresses whitelist addresses.
     * @param categories category in DEX pre-public.
     */
    function setPrePublicWhitelist(address[] memory addresses, uint256[] memory categories) external onlyPrePublicController {
        _setPrePublicWhitelist(addresses, categories);
    }

    /**
     * @notice Updated pre-public round info.
     * @param prePublicRound Pre-public round info.
     */
    function setPrePublicRound(PrePublic memory prePublicRound) external onlyPrePublicController {
        _setPrePublicRound(prePublicRound);
    }

    /**
     * @notice Update max allocation per a wallet.
     * @param newMaxAllocation new max allocation per a wallet.
     */
    function setMaxAllocation(uint256 newMaxAllocation) external onlyMaxAllocationController {
        maxAllocation = newMaxAllocation;
        emit MaxAllocationUpdated(_msgSender(), newMaxAllocation);
    }

    /**
     * @notice Updated uniswap V2 pair.
     * @param pair uniswap V2 pair address.
     * @param tokenPair token in uniswap V2 pair.
     */
    function setUniswapV2Pair(address pair, address tokenPair) external onlyLFController {
        uniswapV2Pair = pair;
        tokenInPair = tokenPair;
        emit UniswapV2PairUpdated(_msgSender(), pair, tokenPair);
    }

    /**
     * @notice Update liquidity fee.
     * @param max max liquidity fee basic points.
     * @param min min liquidity fee basic points.
     */
    function setLiquidityFee(uint256 min, uint256 max) external onlyLFController {
        require(
            min >= 0 &&
            min <= max &&
            max <= 5000,
            "B: invalid values"    
        );
        minLF = min;
        maxLF = max;
        emit LiquidityFeeUpdated(_msgSender(), min, max);
    }

    /**
     * @notice Update liquidity fee reduction
     * @param _LFReduction liquidity fee reduction percent
     */
    function setLFReduction(uint256 _LFReduction) external onlyLFController {
        require(_LFReduction > 0, "B: 0 LF reduction");
        LFReduction = _LFReduction;
        emit LFReductionUpdated(_msgSender(), _LFReduction);
    }

    /**
     * @notice Update liquidity fee period
     * @param _LFPeriod liquidity fee period
     */
    function setLFPeriod(uint256 _LFPeriod) external onlyLFController {
        require(_LFPeriod > 0, "B: 0 LF period");
        LFPeriod = _LFPeriod;
        emit LFPeriodUpdated(_msgSender(), _LFPeriod);
    }

    /**
     * @notice Update swap back enabled status.
     * @param status swap back enabled status.
     */
    function setSwapBackEnabled(bool status) external onlyLFController {
        _swapBackEnabled = status;
        emit SwapBackEnabledUpdated(_msgSender(), status);
    }

    /**
     * @notice Update min swap back amount.
     * @param amount min swap back amount.
     */
    function setMinSwapBackAmount(uint256 amount) external onlyLFController {
        _minSwapBackAmount = amount;
        emit MinSwapBackAmountUpdated(_msgSender(), amount);
    }

    /**
     * @notice Update liquidity fee start time
     * @param _newLFStartTime new liquidity fee start time
     */
    function setLFStartTime(uint256 _newLFStartTime) external onlyLFController {
        require(_newLFStartTime > block.timestamp, "B: invalid start time");
        LFStartTime = _newLFStartTime;
        emit LFStartTimeUpdated(_newLFStartTime);
    }

    /**
     * @notice Update enabled liquidity fee reduction
     * @param status enabled liquidity fee status
     */
    function setIsEnabledLFReduction(bool status) external onlyLFController {
        isEnabledLFReduction = status;
        emit isEnabledLFReductionUpdated(_msgSender(), status);
    }

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
    function bulkPool(address[] memory pools, bool status) external onlyLFController {
        for (uint256 i = 0; i < pools.length; i++) {
            _setPool(pools[i], status);
        }
    }

    /**
     * @notice Updated status of excluded address.
     * @param excludedAddress excluded address
     * @param status status of excluded address
     */
    function setIsExcluded(address excludedAddress, bool status) external onlyTreasuryController() {
        _setIsExcluded(excludedAddress, status);
    }

    /**
     * @notice Updated status of excluded addresses.
     * @param excludedAddresses excluded addresses
     * @param status status of excluded address
     */
    function bulkExcluded(address[] memory excludedAddresses, bool status) external onlyTreasuryController {
        for (uint256 i = 0; i < excludedAddresses.length; i++) {
            _setIsExcluded(excludedAddresses[i], status);
        }
    }

    /**
     * @notice Withdraw stuck token.
     * @param token token address.
     * @param to beneficiary address.
     */
    function withdrawStuckToken(address token, address to) public onlyTreasuryController {
        bool success;
        if (token == address(0)) {
            (success, ) = address(to).call{
                value: address(this).balance
            }("");
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
    function blockAddress(address addr, bool status) public onlyTreasuryController {
        isBlocked[addr] = status;
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

    /**
     * @notice Updated status of excluded address.
     * @param _excludedAddress excluded address
     * @param _status status of excluded address
     */
    function _setIsExcluded(address _excludedAddress, bool _status) internal {
        _isExcluded[_excludedAddress] = _status;
        emit ExcludedUpdated(_excludedAddress, _status);
    }

    /**
     * @notice Updated status of LP pool.
     * @param _pool pool address.
     * @param _status status of the pool.
     */
    function _setPool(address _pool, bool _status) internal {
        _isPool[_pool] = _status;
        emit PoolUpdated(_msgSender(), _pool, _status);
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
     * @notice Updated pre-public whitelist info.
     * @param _addresses whitelist addresses.
     * @param _categories category in DEX pre-public.
     */
    function _setPrePublicWhitelist(address[] memory _addresses, uint256[] memory _categories) private {
        require(_addresses.length == _categories.length, "B: Mismatched length");
        for (uint256 i = 0; i < _addresses.length; i++) {
            _prePublicWhitelist[_addresses[i]] = _categories[i];
        }
        emit PrePublicWhitelistUpdated(_msgSender(), _addresses, _categories);
    }

    /**
     * @notice Swap token for ETH.
     * @param _swapAmount swap tokens amount for ETH.
     */
    function _swapBack(uint256 _swapAmount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = tokenInPair;

        _approve(address(this), address(uniswapV2Router), _swapAmount);

        if (tokenInPair == uniswapV2Router.WETH()) {
            uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                _swapAmount,
                0,
                path,
                address(this),
                block.timestamp
            );
        } else {
            uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
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
    function _addLiquidity(uint256 _liquidityToken0, uint256 _liquidityToken1) internal {
        _approve(address(this), address(uniswapV2Router), _liquidityToken0);
        if (tokenInPair == uniswapV2Router.WETH()) {
            uniswapV2Router.addLiquidityETH{value: _liquidityToken1}(
                address(this),
                _liquidityToken0,
                0,
                0,
                address(0),
                block.timestamp
            );
        } else {
            IERC20(tokenInPair).approve(address(uniswapV2Router), _liquidityToken1);
            uniswapV2Router.addLiquidity(
                address(this),
                tokenInPair,
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
        uint256 _initialToken1Balance;

        if (_minSwapBackAmount == 0) {
            return;
        }

        uint256 liquidityTokens = _minSwapBackAmount.div(2);
        uint256 amounTokensToSwap = _minSwapBackAmount.sub(liquidityTokens);

        if (tokenInPair == uniswapV2Router.WETH()) {
            _initialToken1Balance = address(this).balance;
        } else {
            _initialToken1Balance = IERC20(tokenInPair).balanceOf(address(this));
        }
        
        _swapBack(amounTokensToSwap);

        uint256 _liquidityToken1;

        if (tokenInPair == uniswapV2Router.WETH()) {
            _liquidityToken1 = address(this).balance.sub(_initialToken1Balance);
        } else {
            _liquidityToken1 = IERC20(tokenInPair).balanceOf(address(this)).sub(_initialToken1Balance);
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
    function _update(address from, address to,uint256 amount) internal virtual override {
        if (!_isExcluded[from]) {
            require(!paused(), "B: paused transfer");
        }
        require(!isBlocked[from], "B: blocked from address");
        
        if (amount == 0) {
            super._update(from, to, 0);
            return;
        }
        
        // Guard max allocation
        if (!_isExcluded[from] &&
            !_isExcluded[to] &&
            to != address(0) &&
            to != address(0xdead) &&
            !_swapping
        ) {
            // Pre-public round
            if (_prePublic) {
                uint256 _category = _prePublicWhitelist[to];
                require( _category != 0, "B: only pre-public whitelist");
                PrePublic memory _round = prePublicRounds[_category];
                require(
                    _round.startTime <= block.timestamp &&
                    _round.endTime >= block.timestamp,
                    "B: round not active"    
                );
                require(
                    _coolDown[to] == 0 || 
                    _coolDown[to] + _round.coolDown <= block.timestamp,
                    "B: wait for cool down"
                );
                require(amount <= _round.maxAmountPerBuy, "B: exceed max amount per buy in pre-public");
                _coolDown[to] = block.timestamp;
            }

            // guard on buy
            if (enabledMaxAllocation && _isPool[from]) {
                require(balanceOf(to) + amount <= maxAllocation, "B: exceed max allocation");
            }
        }
        
        if (minLF > 0) {
            // swap back and liquify
            uint256 contractTokenBalance = balanceOf(address(this));
            bool canSwapBackAndLiquify = contractTokenBalance >= _minSwapBackAmount;
            if (
                canSwapBackAndLiquify && 
                _swapBackEnabled &&
                from != uniswapV2Pair &&
                !_swapping
            ) {
                
                _swapping = true;
                _swapBackAndLiquify();
                _swapping = false;
                
            }

            // Extract liquidity fee
            bool _isTakenFee = !_swapping;

            if (_isExcluded[from] || _isExcluded[to]) {
                _isTakenFee = false;
            }

            uint256 _LF = 0;

            if (_isTakenFee) {
                // charge liquidity on sell
                if (_isPool[to] && minLF > 0) {
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
    ///
    /// @dev Authorization logic is only based on the `msg.sender` being an owner of this account,
    ///      or `address(this)`.
    function _authorizeUpgrade(address) internal view virtual override(UUPSUpgradeable) onlyUpgradeController {}
}
