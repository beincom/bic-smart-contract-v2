// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OneCPTestBase} from "../1CPTestBase.t.sol";
import {DiamondCutFacet} from "../../../src/diamond/facets/DiamondCutFacet.sol";
import {LuckyWheelFacet} from "../../../src/1cp/facets/LuckyWheelFacet.sol";
import {EmergencyPauseFacet} from "../../../src/1cp/facets/EmergencyPauseFacet.sol";
import {LibDiamond} from "../../../src/diamond/libraries/LibDiamond.sol";

contract TestERC20 is ERC20 {
    constructor() ERC20("TestERC20", "TEST") {
        _mint(msg.sender, 1e24);
    }

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}

contract LuckyWheelFacetTest is OneCPTestBase {
    TestERC20 public tBIC;
    address public buyer;
    address public creator;
    address public caller;
    address public luckyWheelTreasury;
    uint256 public bufferPostOp;
    uint256 public denominator = 1e10;
    string public orderId = '123dda';

    function setUp() public override virtual {
        super.setUp();
        vm.startPrank(oneCPOwner);
        buyer = address(123456);
        creator = address(12345678);
        caller = address(12345666);
        luckyWheelTreasury = address(1222);
        bufferPostOp = 21000;
        tBIC = new TestERC20();
        LuckyWheelFacet luckyWheelFacet = new LuckyWheelFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](7);
        functionSelectors[0] = luckyWheelFacet.updateLuckyWheelTreasury.selector;
        functionSelectors[1] = luckyWheelFacet.updateLuckyWheelPaymentToken.selector;
        functionSelectors[2] = luckyWheelFacet.updateLuckyWheelBufferPostOp.selector;
        functionSelectors[3] = luckyWheelFacet.buyLuckyWheel.selector;
        functionSelectors[4] = luckyWheelFacet.callBuyLuckyWheel.selector;
        functionSelectors[5] = luckyWheelFacet.getLuckyWheelStorage.selector;
        functionSelectors[6] = luckyWheelFacet.initializeLuckyWheelConfig.selector;

        // prepare diamondCut
        LibDiamond.FacetCut[] memory cuts = new LibDiamond.FacetCut[](1);
        cuts[0] = LibDiamond.FacetCut({
            facetAddress: address(luckyWheelFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        // add lucky wheel facet
        DiamondCutFacet(address(oneCP)).diamondCut(cuts, address(0), "");

        // update lucky wheel config
        LuckyWheelFacet(address(oneCP)).initializeLuckyWheelConfig(
            luckyWheelTreasury,
            address(tBIC),
            bufferPostOp    
        );

        // grant caller access to callBuyLuckyWheel
        setAccessToSelector(luckyWheelFacet.callBuyLuckyWheel.selector, caller, true); 
    }

    function test_config() public {
        vm.startPrank(oneCPOwner);
        vm.expectRevert();
        LuckyWheelFacet(address(oneCP)).initializeLuckyWheelConfig(
            luckyWheelTreasury,
            address(tBIC),
            bufferPostOp    
        );
        (
            uint256 postOpConfig,
            address treasury,
            address payment
            
        ) = LuckyWheelFacet(address(oneCP)).getLuckyWheelStorage();
        assertEq(postOpConfig, bufferPostOp);
        assertEq(treasury, luckyWheelTreasury);
        assertEq(payment, address(tBIC));
    }

    function test_buyLuckyWheel() public {
        vm.startPrank(buyer);
        uint256 buyAmount = 1e24;
        tBIC.mint(buyAmount);
        tBIC.approve(address(oneCP), buyAmount);
        LuckyWheelFacet(address(oneCP)).buyLuckyWheel(
            address(tBIC),
            creator,
            buyAmount,
            orderId
        );
        assertEq(buyAmount, tBIC.balanceOf(luckyWheelTreasury), "Buy amount mismatch");
    }

    function test_callBuyLuckyWheel() public {
        vm.startPrank(buyer);
        tBIC.mint(1e25);
        uint256 buyAmount = 1e24;
        uint256 maxFeePerGas = 1e9;
        uint256 maxPriorityFeePerGas = 1e8;
        uint256 paymentPrice = 1e6 * denominator;
        tBIC.approve(address(oneCP), 1e25);
        vm.startPrank(caller);
        (uint256 actualGasCost, uint256 actualPayment) = LuckyWheelFacet(address(oneCP)).callBuyLuckyWheel(
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
        assertEq(buyAmount + actualPayment, tBIC.balanceOf(luckyWheelTreasury), "buyAmount mismatch");
    }

    function test_failed_callBuyLuckyWheel() public {
        vm.startPrank(buyer);
        tBIC.mint(1e25);
        uint256 buyAmount = 1e24;
        uint256 maxFeePerGas = 1e9;
        uint256 maxPriorityFeePerGas = 1e8;
        uint256 paymentPrice = 1e6 * denominator;
        tBIC.approve(address(oneCP), 1e25);
        vm.startPrank(creator);
        vm.expectRevert();
        (uint256 actualGasCost, uint256 actualPayment) = LuckyWheelFacet(address(oneCP)).callBuyLuckyWheel(
            address(tBIC),
            buyer,
            creator,
            buyAmount,
            orderId,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice
        );
        assertEq(0, tBIC.balanceOf(luckyWheelTreasury), "Surcharge fee mismatch");
        assertEq(0, tBIC.balanceOf(creator), "Received amount fee mismatch");
    }

    function test_pause_buyLuckyWheel() public {
        vm.startPrank(buyer);
        uint256 buyAmount = 1e24;
        tBIC.mint(buyAmount);
        tBIC.approve(address(oneCP), buyAmount);

        vm.startPrank(oneCPOwner);
        EmergencyPauseFacet(payable(address(oneCP))).pauseDiamond();

        vm.expectRevert();
        LuckyWheelFacet(address(oneCP)).buyLuckyWheel(
            address(tBIC),
            creator,
            buyAmount,
            orderId
        );
        assertEq(0, tBIC.balanceOf(luckyWheelTreasury), "expected balance mismatch");
        assertEq(0, tBIC.balanceOf(creator), "Received amount fee mismatch");
    }

    function test_pause_callBuyLuckyWheel() public {
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
        (uint256 actualGasCost, uint256 actualPayment) = LuckyWheelFacet(address(oneCP)).callBuyLuckyWheel(
            address(tBIC),
            buyer,
            creator,
            buyAmount,
            orderId,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice
        );
        assertEq(0, tBIC.balanceOf(luckyWheelTreasury), "Surcharge fee mismatch");
        assertEq(0, tBIC.balanceOf(creator), "Received amount fee mismatch");
    }

    function test_unpause_callBuyLuckyWheel() public {
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
        (uint256 actualGasCost, uint256 actualPayment) = LuckyWheelFacet(address(oneCP)).callBuyLuckyWheel(
            address(tBIC),
            buyer,
            creator,
            buyAmount,
            orderId,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice
        );
        assertEq(0, tBIC.balanceOf(luckyWheelTreasury), "Surcharge fee mismatch");
        assertEq(0, tBIC.balanceOf(creator), "Received amount fee mismatch");

        vm.startPrank(oneCPOwner);
        address[] memory blacklist;
        EmergencyPauseFacet(payable(address(oneCP))).unpauseDiamond(blacklist);

        vm.startPrank(caller);
        (actualGasCost, actualPayment) = LuckyWheelFacet(address(oneCP)).callBuyLuckyWheel(
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
        assertEq(buyAmount + actualPayment, tBIC.balanceOf(luckyWheelTreasury), "buyAmount mismatch");
    }
}