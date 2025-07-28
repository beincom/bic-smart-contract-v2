// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OneCPTestBase} from "../1CPTestBase.t.sol";
import {DiamondCutFacet} from "../../../src/1cp/facets/DiamondCutFacet.sol";
import {MiniGameFacet} from "../../../src/1cp/facets/MiniGameFacet.sol";
import {EmergencyPauseFacet} from "../../../src/1cp/facets/EmergencyPauseFacet.sol";
import {LibDiamond} from "../../../src/1cp/libraries/LibDiamond.sol";

contract TestERC20 is ERC20 {
    constructor() ERC20("TestERC20", "TEST") {
        _mint(msg.sender, 1e24);
    }

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}

contract MiniGameFacetTest is OneCPTestBase {
    TestERC20 public tBIC;
    address public buyer;
    address public creator;
    address public caller;
    address public miniGameTreasury;
    address public rewardPool;
    uint256 public rewardPercent;
    uint256 public bufferPostOp;
    uint256 public denominator = 1e10;
    string public orderId = '123dda';

    function setUp() public override virtual {
        super.setUp();
        vm.startPrank(oneCPOwner);
        buyer = address(123456);
        creator = address(12345678);
        caller = address(12345666);
        miniGameTreasury = address(1222);
        rewardPool = address(2233);
        rewardPercent = 1100;
        bufferPostOp = 21000;

        tBIC = new TestERC20();
        MiniGameFacet miniGameFacet = new MiniGameFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](8);
        functionSelectors[0] = miniGameFacet.getMiniGameStorage.selector;
        functionSelectors[1] = miniGameFacet.initializeMiniGameConfig.selector;
        functionSelectors[2] = miniGameFacet.updateMiniGameTreasury.selector;
        functionSelectors[3] = miniGameFacet.updateMiniGamePaymentToken.selector;
        functionSelectors[4] = miniGameFacet.updateMiniGameBufferPostOp.selector;
        functionSelectors[5] = miniGameFacet.updateRewardConfig.selector;
        functionSelectors[6] = miniGameFacet.buyToolPack.selector;
        functionSelectors[7] = miniGameFacet.callBuyToolPack.selector;

        // prepare diamondCut
        LibDiamond.FacetCut[] memory cuts = new LibDiamond.FacetCut[](1);
        cuts[0] = LibDiamond.FacetCut({
            facetAddress: address(miniGameFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        // add mini game facet
        DiamondCutFacet(address(oneCP)).diamondCut(cuts, address(0), "");

        // update mini game config
        MiniGameFacet(address(oneCP)).initializeMiniGameConfig(
            bufferPostOp,
            rewardPercent,
            miniGameTreasury,
            rewardPool,
            address(tBIC)
        );

        // grant caller access to callToolPack
        setAccessToSelector(miniGameFacet.callBuyToolPack.selector, caller, true); 
    }

    function test_config() public {
        vm.startPrank(oneCPOwner);
        vm.expectRevert();
        MiniGameFacet(address(oneCP)).initializeMiniGameConfig(
            bufferPostOp,
            rewardPercent,
            miniGameTreasury,
            rewardPool,
            address(tBIC)    
        );
        (
            uint256 postOpConfig,
            uint256 rewardPercentConfig,
            address treasury,
            address rewardPoolConfig,
            address payment
            
        ) = MiniGameFacet(address(oneCP)).getMiniGameStorage();
        assertEq(postOpConfig, bufferPostOp);
        assertEq(treasury, miniGameTreasury);
        assertEq(payment, address(tBIC));
        assertEq(rewardPercent, rewardPercentConfig);
        assertEq(rewardPool, rewardPoolConfig);
    }

    function test_buyToolPack() public {
        vm.startPrank(buyer);
        uint256 buyAmount = 1e24;
        tBIC.mint(buyAmount);
        tBIC.approve(address(oneCP), buyAmount);
        MiniGameFacet(address(oneCP)).buyToolPack(
            address(tBIC),
            creator,
            buyAmount,
            orderId
        );

        uint256 rewardAmount = buyAmount * rewardPercent / 10000;
        assertEq(buyAmount - rewardAmount, tBIC.balanceOf(miniGameTreasury), "Balance expected mismatch");
        assertEq(rewardAmount, tBIC.balanceOf(rewardPool), "Balance expected mismatch");
    }

    function test_callBuyToolPack() public {
        vm.startPrank(buyer);
        tBIC.mint(1e25);
        uint256 buyAmount = 1e24;
        uint256 maxFeePerGas = 1e9;
        uint256 maxPriorityFeePerGas = 1e8;
        uint256 paymentPrice = 1e6 * denominator;
        tBIC.approve(address(oneCP), 1e25);
        vm.startPrank(caller);
        (uint256 actualGasCost, uint256 actualPayment) = MiniGameFacet(address(oneCP)).callBuyToolPack(
            address(tBIC),
            buyer,
            creator,
            buyAmount,
            orderId,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice
        );
        assertEq(actualGasCost * paymentPrice / denominator, actualPayment, "Gas Payment mismatch");
        uint256 rewardAmount = buyAmount * rewardPercent / 10000;
        assertEq(buyAmount - rewardAmount + actualPayment, tBIC.balanceOf(miniGameTreasury), "Balance expected mismatch");
        assertEq(rewardAmount, tBIC.balanceOf(rewardPool), "Balance expected mismatch");
    }

    function test_failed_callBuyToolPack() public {
        vm.startPrank(buyer);
        tBIC.mint(1e25);
        uint256 buyAmount = 1e24;
        uint256 maxFeePerGas = 1e9;
        uint256 maxPriorityFeePerGas = 1e8;
        uint256 paymentPrice = 1e6 * denominator;
        tBIC.approve(address(oneCP), 1e25);
        vm.startPrank(creator);
        vm.expectRevert();
        (uint256 actualGasCost, uint256 actualPayment) = MiniGameFacet(address(oneCP)).callBuyToolPack(
            address(tBIC),
            buyer,
            creator,
            buyAmount,
            orderId,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice
        );
        assertEq(0, tBIC.balanceOf(miniGameTreasury), "Surcharge fee mismatch");
        assertEq(0, tBIC.balanceOf(creator), "Received amount fee mismatch");
    }

    function test_pause_buyToolPack() public {
        vm.startPrank(buyer);
        uint256 buyAmount = 1e24;
        tBIC.mint(buyAmount);
        tBIC.approve(address(oneCP), buyAmount);

        vm.startPrank(oneCPOwner);
        EmergencyPauseFacet(payable(address(oneCP))).pauseDiamond();

        vm.expectRevert();
        MiniGameFacet(address(oneCP)).buyToolPack(
            address(tBIC),
            creator,
            buyAmount,
            orderId
        );
        assertEq(0, tBIC.balanceOf(miniGameTreasury), "expected balance mismatch");
        assertEq(0, tBIC.balanceOf(creator), "Received amount fee mismatch");
    }

    function test_pause_callBuyToolPack() public {
        vm.startPrank(buyer);
        tBIC.mint(1e25);
        uint256 buyAmount = 1e24;
        uint256 maxFeePerGas = 1e9;
        uint256 maxPriorityFeePerGas = 1e8;
        uint256 paymentPrice = 1e6 * denominator;
        tBIC.approve(address(oneCP), 1e25);

        vm.startPrank(pauserWallet);
        EmergencyPauseFacet(payable(address(oneCP))).pauseDiamond();

        vm.startPrank(caller);
        vm.expectRevert();
        (uint256 actualGasCost, uint256 actualPayment) = MiniGameFacet(address(oneCP)).callBuyToolPack(
            address(tBIC),
            buyer,
            creator,
            buyAmount,
            orderId,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice
        );
        assertEq(0, tBIC.balanceOf(miniGameTreasury), "Surcharge fee mismatch");
        assertEq(0, tBIC.balanceOf(creator), "Received amount fee mismatch");
    }

    function test_unpause_callBuyToolPack() public {
        vm.startPrank(buyer);
        tBIC.mint(1e25);
        uint256 buyAmount = 1e24;
        uint256 maxFeePerGas = 1e9;
        uint256 maxPriorityFeePerGas = 1e8;
        uint256 paymentPrice = 1e6 * denominator;
        tBIC.approve(address(oneCP), 1e25);

        vm.startPrank(pauserWallet);
        EmergencyPauseFacet(payable(address(oneCP))).pauseDiamond();

        vm.startPrank(caller);
        vm.expectRevert();
        (uint256 actualGasCost, uint256 actualPayment) = MiniGameFacet(address(oneCP)).callBuyToolPack(
            address(tBIC),
            buyer,
            creator,
            buyAmount,
            orderId,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice
        );
        assertEq(0, tBIC.balanceOf(miniGameTreasury), "Surcharge fee mismatch");
        assertEq(0, tBIC.balanceOf(creator), "Received amount fee mismatch");

        vm.startPrank(oneCPOwner);
        address[] memory blacklist;
        EmergencyPauseFacet(payable(address(oneCP))).unpauseDiamond(blacklist);

        vm.startPrank(caller);
        (actualGasCost, actualPayment) = MiniGameFacet(address(oneCP)).callBuyToolPack(
            address(tBIC),
            buyer,
            creator,
            buyAmount,
            orderId,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice
        );
        assertEq(actualGasCost * paymentPrice / denominator, actualPayment, "Gas Payment mismatch");
        uint256 rewardAmount = buyAmount * rewardPercent / 10000;
        assertEq(buyAmount - rewardAmount + actualPayment, tBIC.balanceOf(miniGameTreasury), "Balance expected mismatch");
        assertEq(rewardAmount, tBIC.balanceOf(rewardPool), "Balance expected mismatch");
    }
}