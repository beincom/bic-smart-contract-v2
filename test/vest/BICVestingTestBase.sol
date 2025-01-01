// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {BICVestingFactory} from "../../src/vest/BICVestingFactory.sol";
import {BICVesting} from "../../src/vest/BICVesting.sol";

contract TestERC20 is ERC20 {
    constructor(address owner) ERC20("Test ERC20", "tERC20") {
        _mint(owner, 1e27);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract BICVestingTestBase is Test {
    struct CreateRedeem {
        address token;
        uint256 totalAmount;
        address[] beneficiaries;
        uint16[] allocations;
        uint64 duration;
        uint64 redeemRate;
    }

    BICVestingFactory public bicVestingFactory;
    TestERC20 public testERC20;

    uint256 owner_private_key = 0xb1c;
    address owner = vm.addr(owner_private_key);
    uint256 redeemer1_private_key = 0xb2c;
    address redeemer1 = vm.addr(redeemer1_private_key);
    uint256 redeemer2_private_key = 0xb3c;
    address redeemer2 = vm.addr(redeemer2_private_key);

    CreateRedeem public redeem1;
    address[] beneficiaries;
    uint16[] allocations;

    function setUp() public virtual {
        bicVestingFactory = new BICVestingFactory(owner);
        testERC20 = new TestERC20(owner);

        vm.startPrank(owner);
        testERC20.transfer(
            address(bicVestingFactory),
            testERC20.balanceOf(owner)
        );

        beneficiaries = new address[](2);
        beneficiaries[0] = redeemer1;
        beneficiaries[1] = redeemer2;

        allocations = new uint16[](2);
        allocations[0] = 7000;
        allocations[1] = 3000;

        redeem1 = CreateRedeem({
            token: address(testERC20),
            totalAmount: 1e21,
            beneficiaries: beneficiaries,
            allocations: allocations,
            duration: 1000,
            redeemRate: 200
        });
        createVesting(redeem1);
    }

    function isValidAllocations(uint16[] memory _allocations) internal pure returns (bool) {
        uint256 sum = 0;
        for (uint256 i = 0; i < _allocations.length; i++) {
            sum += _allocations[i];
            if (sum > 10_000) {
                return false;
            }
        }
        return sum == 10_000;
    }


    function createVesting(CreateRedeem memory info) public {
        vm.startPrank(owner);
        bicVestingFactory.createRedeem(
            info.token,
            info.totalAmount,
            info.beneficiaries,
            info.allocations,
            info.duration,
            info.redeemRate
        );
        vm.stopPrank();
    }

    function getVestingContract(
        CreateRedeem memory info
    ) public view returns (address) {
        return
            bicVestingFactory.computeRedeem(
                info.token,
                info.totalAmount,
                info.beneficiaries,
                info.allocations,
                info.duration,
                info.redeemRate
            );
    }

    function test_checking_vesting_info() public view {
        address vestingContract = getVestingContract(redeem1);
        BICVesting bicVesting = BICVesting(vestingContract);
        uint64 DENOMINATOR = bicVesting.DENOMINATOR();
        uint256 amountPerDuration = redeem1.totalAmount * redeem1.redeemRate / DENOMINATOR;
        
        assertEq(redeem1.token, bicVesting.erc20());
        assertEq(redeem1.totalAmount, bicVesting.redeemTotalAmount());
        assertEq(redeem1.redeemRate, bicVesting.redeemRate());
        assertEq(redeem1.duration, bicVesting.duration());
        assertEq(amountPerDuration, bicVesting.amountPerDuration());
    }
}
