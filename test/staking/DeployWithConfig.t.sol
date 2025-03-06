// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {TieredStakingPool} from "../../src/staking/TieredStakingPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";

contract TestERC20 is ERC20 {
    constructor() ERC20("TestERC20", "TEST") {
        _mint(msg.sender, 1e24);
    }

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}

contract DeployWithConfigTest is Script, Test {
    using stdJson for string;

    struct Tier {
        uint256 maxTokens;
        uint256 annualInterestRate;
        uint256 lockDuration;
    }

    string public root;
    TieredStakingPool public tieredStakingPool;
    TestERC20 public stakingToken;
    address public stakingOwner;
    Tier[] public tiers;

    function setUp() public {
        root = vm.projectRoot();
        stakingOwner = address(0x1213);
        stakingToken = new TestERC20();
        tieredStakingPool = new TieredStakingPool(IERC20(stakingToken), stakingOwner);
        console.log("Tiered Staking Pool deployed at:", address(tieredStakingPool));
        deployWithConfig();
    }

    function deployWithConfig() internal {
        // load config
        string memory path = string.concat(root, "/config/tier_duration_6.json");
        string memory json = vm.readFile(path);
        bytes memory rawConfig = json.parseRaw("tiers");
        tiers = abi.decode(rawConfig, (Tier[]));
        vm.startPrank(stakingOwner);

        for (uint256 i = 0; i < tiers.length; i++) {
            tieredStakingPool.addTier(
                tiers[i].maxTokens * 1e18,
                tiers[i].annualInterestRate * 100,
                tiers[i].lockDuration * 86400
            );
        }
    }

    function test_checkConfig() public {
        (uint256 maxTokens,,,) = tieredStakingPool.tiers(0);
        assertEq(maxTokens, tiers[0].maxTokens);
    }
}