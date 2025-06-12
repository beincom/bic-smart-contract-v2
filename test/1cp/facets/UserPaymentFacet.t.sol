// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OneCPTestBase} from "../1CPTestBase.t.sol";
import {DiamondCutFacet} from "../../../src/1cp/facets/DiamondCutFacet.sol";
import {UserPaymentFacet} from "../../../src/1cp/facets/UserPaymentFacet.sol";
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

contract UserPaymentFacetTest is OneCPTestBase {
    TestERC20 public tBIC;
    address public buyer;
    address public seller;
    address public caller;
    address public userTreasury;
    uint256 public bufferPostOp;
    uint256 public denominator = 1e10;
    string public orderId = '123dda';

    function setUp() public override virtual {
        super.setUp();
        vm.startPrank(oneCPOwner);
        buyer = address(123456);
        seller = address(12345678);
        caller = address(12345666);
        userTreasury = address(1222);
        bufferPostOp = 21000;
        tBIC = new TestERC20();
        UserPaymentFacet userPaymentFacet = new UserPaymentFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](7);
        functionSelectors[0] = userPaymentFacet.updateUserTreasury.selector;
        functionSelectors[1] = userPaymentFacet.updateUserPaymentToken.selector;
        functionSelectors[2] = userPaymentFacet.updateUserBufferPostOp.selector;
        functionSelectors[3] = userPaymentFacet.buyAccount.selector;
        functionSelectors[4] = userPaymentFacet.callBuyAccount.selector;
        functionSelectors[5] = userPaymentFacet.getUserPaymentStorage.selector;
        functionSelectors[6] = userPaymentFacet.initializeUserPaymentConfig.selector;

        // prepare diamondCut
        LibDiamond.FacetCut[] memory cuts = new LibDiamond.FacetCut[](1);
        cuts[0] = LibDiamond.FacetCut({
            facetAddress: address(userPaymentFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        // add donation facet
        DiamondCutFacet(address(oneCP)).diamondCut(cuts, address(0), "");

        // update donation config
        UserPaymentFacet(address(oneCP)).initializeUserPaymentConfig(
            userTreasury,
            address(tBIC),
            bufferPostOp    
        );
        

        // grant caller access to callDonation
        setAccessToSelector(userPaymentFacet.callBuyAccount.selector, caller, true); 
    }

    function test_config() public {
        vm.startPrank(oneCPOwner);
        vm.expectRevert();
        UserPaymentFacet(address(oneCP)).initializeUserPaymentConfig(
            userTreasury,
            address(tBIC),
            bufferPostOp    
        );
        (
            uint256 postOpConfig,
            address treasury,
            address payment
            
        ) = UserPaymentFacet(address(oneCP)).getUserPaymentStorage();
        assertEq(postOpConfig, bufferPostOp);
        assertEq(treasury, userTreasury);
        assertEq(payment, address(tBIC));
    }

    function test_buyContent() public {
        vm.startPrank(buyer);
        uint256 buyAmount = 1e24;
        tBIC.mint(buyAmount);
        tBIC.approve(address(oneCP), buyAmount);
        UserPaymentFacet(address(oneCP)).buyAccount(
            address(tBIC),
            seller,
            buyAmount,
            orderId
        );
        assertEq(buyAmount, tBIC.balanceOf(userTreasury), "Received amount fee mismatch");
    }

    function test_callBuyContent() public {
        vm.startPrank(buyer);
        tBIC.mint(1e25);
        uint256 buyAmount = 1e24;
        uint256 maxFeePerGas = 1e9;
        uint256 maxPriorityFeePerGas = 1e8;
        uint256 paymentPrice = 1e6 * denominator;
        tBIC.approve(address(oneCP), 1e25);
        vm.startPrank(caller);
        (uint256 actualGasCost, uint256 actualPayment) = UserPaymentFacet(address(oneCP)).callBuyAccount(
            address(tBIC),
            buyer,
            seller,
            buyAmount,
            orderId,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice
        );
        assertEq(actualGasCost * paymentPrice / denominator, actualPayment, "Gas Payment mismatch");
        assertEq(buyAmount + actualPayment, tBIC.balanceOf(userTreasury), "Surcharge fee mismatch");
    }

    function test_failed_callBuyContent() public {
        vm.startPrank(buyer);
        tBIC.mint(1e25);
        uint256 buyAmount = 1e24;
        uint256 maxFeePerGas = 1e9;
        uint256 maxPriorityFeePerGas = 1e8;
        uint256 paymentPrice = 1e6 * denominator;
        tBIC.approve(address(oneCP), 1e25);
        vm.startPrank(seller);
        vm.expectRevert();
        (uint256 actualGasCost, uint256 actualPayment) = UserPaymentFacet(address(oneCP)).callBuyAccount(
            address(tBIC),
            buyer,
            seller,
            buyAmount,
            orderId,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice
        );
        assertEq(0, tBIC.balanceOf(userTreasury), "Surcharge fee mismatch");
        assertEq(0, tBIC.balanceOf(seller), "Received amount fee mismatch");
    }

    function test_pause_buyContent() public {
        vm.startPrank(buyer);
        uint256 buyAmount = 1e24;
        tBIC.mint(buyAmount);
        tBIC.approve(address(oneCP), buyAmount);

        vm.startPrank(oneCPOwner);
        EmergencyPauseFacet(payable(address(oneCP))).pauseDiamond();

        vm.expectRevert();
        UserPaymentFacet(address(oneCP)).buyAccount(
            address(tBIC),
            seller,
            buyAmount,
            orderId
        );
        assertEq(0, tBIC.balanceOf(userTreasury), "Surcharge fee mismatch");
        assertEq(0, tBIC.balanceOf(seller), "Received amount fee mismatch");
    }

    function test_pause_callBuyContent() public {
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
        (uint256 actualGasCost, uint256 actualPayment) = UserPaymentFacet(address(oneCP)).callBuyAccount(
            address(tBIC),
            buyer,
            seller,
            buyAmount,
            orderId,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice
        );
        assertEq(0, tBIC.balanceOf(userTreasury), "Surcharge fee mismatch");
        assertEq(0, tBIC.balanceOf(seller), "Received amount fee mismatch");
    }

    function test_unpause_callBuyContent() public {
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
        (uint256 actualGasCost, uint256 actualPayment) = UserPaymentFacet(address(oneCP)).callBuyAccount(
            address(tBIC),
            buyer,
            seller,
            buyAmount,
            orderId,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice
        );
        assertEq(0, tBIC.balanceOf(userTreasury), "Surcharge fee mismatch");
        assertEq(0, tBIC.balanceOf(seller), "Received amount fee mismatch");

        vm.startPrank(oneCPOwner);
        address[] memory blacklist;
        EmergencyPauseFacet(payable(address(oneCP))).unpauseDiamond(blacklist);

        vm.startPrank(caller);
        (actualGasCost, actualPayment) = UserPaymentFacet(address(oneCP)).callBuyAccount(
            address(tBIC),
            buyer,
            seller,
            buyAmount,
            orderId,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice
        );
        assertEq(actualGasCost * paymentPrice / denominator, actualPayment, "Gas Payment mismatch");
        assertEq(buyAmount + actualPayment, tBIC.balanceOf(userTreasury), "Surcharge fee mismatch");
    }
}