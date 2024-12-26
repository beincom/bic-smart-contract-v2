// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@account-abstraction/contracts/core/EntryPoint.sol";
import {BicTokenPaymaster} from "../../src/BicTokenPaymaster.sol";
import "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "../../script/UniswapV2Deployer.s.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract BicTokenPaymasterTestBase is Test {
    BicTokenPaymaster public bic;
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
            "BicTokenPaymaster.sol",
            abi.encodeCall(
                BicTokenPaymaster.initialize,
                (address(entrypoint), owner, signers)
            )
        );
        bic = BicTokenPaymaster(payable(proxy));

        vm.prank(owner);
        bic.transfer(holder1, holder1_init_amount);
    }

    // The storage location constant from BicStorage
    bytes32 private constant BicTokenPaymasterStorageLocation =
    0xd959cca23720948e5f992e1bef099a518994cc8b384c796f2b25ba30718fb300;

    // Offset of _uniswapV2Pair in the BicStorage.Data struct
    uint256 private constant UNISWAP_V2_PAIR_OFFSET = 8;

    function getUniswapV2Pair() public view returns (address) {
        address uniswapV2Pair = address(
            uint160(
                uint256(
                    vm.load(
                        address(bic),
                        bytes32(uint256(BicTokenPaymasterStorageLocation) + UNISWAP_V2_PAIR_OFFSET)
                    )
                )
            )
        );
        return uniswapV2Pair;
    }

    // Offset of _accumulatedLF in the BicStorage.Data struct
    uint256 private constant ACCUMULATED_LF_OFFSET = 6;
    function getAccumulatedLF() public view returns (uint256) {
        return uint256(
            vm.load(
                address(bic),
                bytes32(uint256(BicTokenPaymasterStorageLocation) + ACCUMULATED_LF_OFFSET)
            )
        );
    }

    // Offset of _LFReduction in the BicStorage.Data struct
    uint256 private constant LF_REDUCTION_OFFSET = 1;
    function getLFReduction() public view returns (uint256) {
        return uint256(
            vm.load(
                address(bic),
                bytes32(uint256(BicTokenPaymasterStorageLocation) + LF_REDUCTION_OFFSET)
            )
        );
    }

    uint256 private constant LF_PERIOD_OFFSET = 2;
    function getLFPeriod() public view returns (uint256) {
        return uint256(
            vm.load(
                address(bic),
                bytes32(uint256(BicTokenPaymasterStorageLocation) + LF_PERIOD_OFFSET)
            )
        );
    }

    uint256 private constant MAX_LF_OFFSET = 3;
    function getMaxLF() public view returns (uint256) {
        return uint256(
            vm.load(
                address(bic),
                bytes32(uint256(BicTokenPaymasterStorageLocation) + MAX_LF_OFFSET)
            )
        );
    }

    uint256 private constant MIN_LF_OFFSET = 4;
    function getMinLF() public view returns (uint256) {
        return uint256(
            vm.load(
                address(bic),
                bytes32(uint256(BicTokenPaymasterStorageLocation) + MIN_LF_OFFSET)
            )
        );
    }
}
