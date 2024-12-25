// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@account-abstraction/contracts/core/EntryPoint.sol";
import {B139} from "../../src/B139.sol";
import "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "../../script/UniswapV2Deployer.s.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract B139TestBase is Test {
    B139 public bic;
    uint256 owner_private_key = 0xb1c;
    address owner = vm.addr(owner_private_key);
    uint256 dev_private_key = 0x238;
    address dev = vm.addr(dev_private_key);
    uint256 public holder1_pkey = 0x1;
    address public holder1 = vm.addr(holder1_pkey);
    uint256 public holder1_init_amount = 10000 * 1e18;
    address[] signers = [owner, dev];
    IUniswapV2Factory public uniswapV2Factory;
    IUniswapV2Router02 public uniswapV2Router;
    WETH public weth;
    EntryPoint entrypoint;

    function setUp() public virtual {
        entrypoint = new EntryPoint();

        UniswapV2Deployer deployer = new UniswapV2Deployer();
        deployer.run();
        uniswapV2Factory = IUniswapV2Factory(deployer.UNISWAP_V2_FACTORY());
        uniswapV2Router = IUniswapV2Router02(deployer.UNISWAP_V2_ROUTER());
        weth = WETH(payable(deployer.WETH()));

        vm.prank(dev);
        address proxy = Upgrades.deployUUPSProxy(
            "B139.sol",
            abi.encodeCall(
                B139.initialize,
                (address(entrypoint), owner, signers)
            )
        );
        bic = B139(payable(proxy));

        vm.prank(owner);
        bic.transfer(holder1, holder1_init_amount);
    }
}