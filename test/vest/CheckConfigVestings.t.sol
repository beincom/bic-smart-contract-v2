// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BICVestingTestBase} from "./BICVestingTestBase.sol";
import {BICVesting} from "../../src/vest/BICVesting.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BICVestingTest is BICVestingTestBase {
    uint64 public constant DENOMINATOR = 10_000;
    struct VestingConfig {
        uint256 totalAmount;
        address[] beneficiaries;
        uint16[] allocations;
        uint64 durationSeconds;
        uint64 redeemRate;
    }
    BICVesting public constant STARTEGIC_PARNET = BICVesting(0x024bBBE12CF4fe894BFfFea0647257aA1183597B);
    BICVesting public constant CORE_TEAM = BICVesting(0x49fcD47A8caf052C80Ffc4Db9Ea24a83EcC69ce5);
    BICVesting public constant AIRDROP_CAMPAIGNS = BICVesting(0xBB6652A8f32a147c3B0a8d0dD3b89B83Fa85fcA5);
    BICVesting public constant COMMUNITY_AND_ECOSYSTEM = BICVesting(0x197f5D9110315544d057b1A463723363769BF01a);
    BICVesting public constant OPERATION_FUNDS = BICVesting(0x3EAB71B2b7C42B17e0666cBe6a943AD35Aa395ec);
    BICVesting public constant FOUNDATION_RESERVES = BICVesting(0xB457D6f060Ccd8F6510c776e414F905ed34CB28A);

    
    mapping(address => VestingConfig) public vestingConfigs;
    function setUp() public override {
        super.setUp();

        // Strategic Partner
        vestingConfigs[address(STARTEGIC_PARNET)] = VestingConfig({
            totalAmount: 100_000_000 ** 18,
            beneficiaries: [address(0x110f3C3b9b8fAD21B2e5677b092E867C99732134)],
            allocations: [10000],
            durationSeconds: 7*84600,
            redeemRate: 30
        });
        // Core Team
        vestingConfigs[address(CORE_TEAM)] = VestingConfig({
            totalAmount: 300_000_000 ** 18,
            beneficiaries: [address(0x399597fA5cf537681F80Dc988E42b5BCaAd8b5EE)],
            allocations: [10000],
            durationSeconds: 7*84600,
            redeemRate: 30
        });
        // Airdrop Campaigns
        vestingConfigs[address(AIRDROP_CAMPAIGNS)] = VestingConfig({
            totalAmount: 300_000_000 ** 18,
            beneficiaries: [address(0x4A96b7cC073751Ef18085c440D6d2d63a40b896D)],
            allocations: [10000],
            durationSeconds: 7*84600,
            redeemRate: 50
        });
        // Community and Ecosystem
        vestingConfigs[address(COMMUNITY_AND_ECOSYSTEM)] = VestingConfig({
            totalAmount: 400_000_000 ** 18,
            beneficiaries: [address(0x96949bccDa39A15004dd0b58556a880499745328)],
            allocations: [10000],
            durationSeconds: 7*84600,
            redeemRate: 50
        });
        // Operation funds
        vestingConfigs[address(OPERATION_FUNDS)] = VestingConfig({
            totalAmount: 500_000_000 ** 18,
            beneficiaries: [address(0xba7a4e84257E151eD276F991D6DcD6d33F55dc69)],
            allocations: [10000],
            durationSeconds: 7*84600,
            redeemRate: 30
        });
        // Foundation Reserves
        vestingConfigs[address(FOUNDATION_RESERVES)] = VestingConfig({
            totalAmount: 1_750_000_000 ** 18,
            beneficiaries: [address(0x9BB26Ce991F3b447804066E67298F5Ca0b54dD89)],
            allocations: [10000],
            durationSeconds: 7*84600,
            redeemRate: 10
        });
    }

    function test_CheckConfigVestings() public {
        checkConfigVesting(address(0x024bBBE12CF4fe894BFfFea0647257aA1183597B));
        checkConfigVesting(address(0x49fcD47A8caf052C80Ffc4Db9Ea24a83EcC69ce5));
        checkConfigVesting(address(0xBB6652A8f32a147c3B0a8d0dD3b89B83Fa85fcA5));
        checkConfigVesting(address(0x197f5D9110315544d057b1A463723363769BF01a));
        checkConfigVesting(address(0x3EAB71B2b7C42B17e0666cBe6a943AD35Aa395ec));
        checkConfigVesting(address(0xB457D6f060Ccd8F6510c776e414F905ed34CB28A));
    }

    function checkConfigVesting(BICVesting vestingAddress) public {
        // Get onchain vesting configs
        VestingConfig vestingConfig = vestingConfigs[vestingAddress];
        
        BICVesting.Data memory data = BICVesting(vestingAddress).getInformation();

        assertEq(data.beneficiaries[0], vestingConfig.beneficiaries[0]);
        assertEq(data.allocations[0], vestingConfig.allocations[0]);
        assertEq(data.durationSeconds, vestingConfig.durationSeconds);
        assertEq(data.redeemRate, vestingConfig.redeemRate);
    }
}