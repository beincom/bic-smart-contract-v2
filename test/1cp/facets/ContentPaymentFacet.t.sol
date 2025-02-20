// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OneCPTestBase} from "../1CPTestBase.t.sol";
import {DiamondCutFacet} from "../../../src/1cp/facets/DiamondCutFacet.sol";
import {ContentPaymentFacet} from "../../../src/1cp/facets/ContentPaymentFacet.sol";
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

contract ContentPaymentFacetTest is OneCPTestBase {
    TestERC20 public tBIC;
    address public buyer;
    address public creator;
    address public caller;
    address public contentTreasury;
    uint256 public surchargeFee;
    uint256 public bufferPostOp;
    string public customerId = '123dda';
    string public contentId = '12ssdfds';

    function setUp() public override virtual {
        super.setUp();
        vm.startPrank(oneCPOwner);
        buyer = address(123456);
        creator = address(12345678);
        caller = address(12345666);
        contentTreasury = address(1222);
        surchargeFee = 1000;
        bufferPostOp = 21000;
        tBIC = new TestERC20();
        ContentPaymentFacet contentPaymentFacet = new ContentPaymentFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](6);
        functionSelectors[0] = contentPaymentFacet.updateContentTreasury.selector;
        functionSelectors[1] = contentPaymentFacet.updatePaymentToken.selector;
        functionSelectors[2] = contentPaymentFacet.updateSurchargeFee.selector;
        functionSelectors[3] = contentPaymentFacet.updateBufferPostOp.selector;
        functionSelectors[4] = contentPaymentFacet.buyContent.selector;
        functionSelectors[5] = contentPaymentFacet.callBuyContent.selector;

        // prepare diamondCut
        LibDiamond.FacetCut[] memory cuts = new LibDiamond.FacetCut[](1);
        cuts[0] = LibDiamond.FacetCut({
            facetAddress: address(contentPaymentFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        // add donation facet
        DiamondCutFacet(address(oneCP)).diamondCut(cuts, address(0), "");

        // update donation config
        ContentPaymentFacet(address(oneCP)).updateContentTreasury(contentTreasury);
        ContentPaymentFacet(address(oneCP)).updatePaymentToken(address(tBIC));
        ContentPaymentFacet(address(oneCP)).updateSurchargeFee(surchargeFee);
        ContentPaymentFacet(address(oneCP)).updateBufferPostOp(bufferPostOp);

        // grant caller access to callDonation
        setAccessToSelector(contentPaymentFacet.callBuyContent.selector, caller, true); 
    }

    function test_buyContent() public {
        vm.startPrank(buyer);
        uint256 buyAmount = 1e24;
        tBIC.mint(buyAmount);
        tBIC.approve(address(oneCP), buyAmount);
        ContentPaymentFacet(address(oneCP)).buyContent(
            address(tBIC),
            creator,
            buyAmount,
            customerId,
            contentId
        );
        assertEq(buyAmount * surchargeFee / 10_000, tBIC.balanceOf(contentTreasury), "Surcharge fee mismatch");
        assertEq(buyAmount - (buyAmount * surchargeFee / 10_000), tBIC.balanceOf(creator), "Received amount fee mismatch");
    }

    function test_callBuyContent() public {
        vm.startPrank(buyer);
        tBIC.mint(1e25);
        uint256 buyAmount = 1e24;
        uint256 maxFeePerGas = 1e9;
        uint256 maxPriorityFeePerGas = 1e8;
        uint256 paymentPrice = 1e6;
        tBIC.approve(address(oneCP), 1e25);
        vm.startPrank(caller);
        (uint256 actualGasCost, uint256 actualPayment) = ContentPaymentFacet(address(oneCP)).callBuyContent(
            buyAmount,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice,
            address(tBIC),
            buyer,
            creator,
            customerId,
            contentId
        );
        assertEq(actualGasCost * paymentPrice, actualPayment, "Gas Payment mismatch");
        assertEq((buyAmount * surchargeFee / 10_000) + actualPayment, tBIC.balanceOf(contentTreasury), "Surcharge fee mismatch");
        assertEq(buyAmount - (buyAmount * surchargeFee / 10_000), tBIC.balanceOf(creator), "Received amount fee mismatch");
    }

    function test_failed_callBuyContent() public {
        vm.startPrank(buyer);
        tBIC.mint(1e25);
        uint256 buyAmount = 1e24;
        uint256 maxFeePerGas = 1e9;
        uint256 maxPriorityFeePerGas = 1e8;
        uint256 paymentPrice = 1e6;
        tBIC.approve(address(oneCP), 1e25);
        vm.startPrank(creator);
        vm.expectRevert();
        (uint256 actualGasCost, uint256 actualPayment) = ContentPaymentFacet(address(oneCP)).callBuyContent(
            buyAmount,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice,
            address(tBIC),
            buyer,
            creator,
            customerId,
            contentId
        );
        assertEq(0, tBIC.balanceOf(contentTreasury), "Surcharge fee mismatch");
        assertEq(0, tBIC.balanceOf(creator), "Received amount fee mismatch");
    }

    function test_pause_buyContent() public {
        vm.startPrank(buyer);
        uint256 buyAmount = 1e24;
        tBIC.mint(buyAmount);
        tBIC.approve(address(oneCP), buyAmount);

        vm.startPrank(oneCPOwner);
        EmergencyPauseFacet(payable(address(oneCP))).pauseDiamond();

        vm.expectRevert();
        ContentPaymentFacet(address(oneCP)).buyContent(
            address(tBIC),
            creator,
            buyAmount,
            customerId,
            contentId
        );
        assertEq(0, tBIC.balanceOf(contentTreasury), "Surcharge fee mismatch");
        assertEq(0, tBIC.balanceOf(creator), "Received amount fee mismatch");
    }

    function test_pause_callBuyContent() public {
        vm.startPrank(buyer);
        tBIC.mint(1e25);
        uint256 buyAmount = 1e24;
        uint256 maxFeePerGas = 1e9;
        uint256 maxPriorityFeePerGas = 1e8;
        uint256 paymentPrice = 1e6;
        tBIC.approve(address(oneCP), 1e25);

        vm.startPrank(pauserWallet);
        EmergencyPauseFacet(payable(address(oneCP))).pauseDiamond();

        vm.startPrank(caller);
        vm.expectRevert();
        (uint256 actualGasCost, uint256 actualPayment) = ContentPaymentFacet(address(oneCP)).callBuyContent(
            buyAmount,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice,
            address(tBIC),
            buyer,
            creator,
            customerId,
            contentId
        );
        assertEq(0, tBIC.balanceOf(contentTreasury), "Surcharge fee mismatch");
        assertEq(0, tBIC.balanceOf(creator), "Received amount fee mismatch");
    }

    function test_unpause_callBuyContent() public {
        vm.startPrank(buyer);
        tBIC.mint(1e25);
        uint256 buyAmount = 1e24;
        uint256 maxFeePerGas = 1e9;
        uint256 maxPriorityFeePerGas = 1e8;
        uint256 paymentPrice = 1e6;
        tBIC.approve(address(oneCP), 1e25);

        vm.startPrank(pauserWallet);
        EmergencyPauseFacet(payable(address(oneCP))).pauseDiamond();

        vm.startPrank(caller);
        vm.expectRevert();
        (uint256 actualGasCost, uint256 actualPayment) = ContentPaymentFacet(address(oneCP)).callBuyContent(
            buyAmount,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice,
            address(tBIC),
            buyer,
            creator,
            customerId,
            contentId
        );
        assertEq(0, tBIC.balanceOf(contentTreasury), "Surcharge fee mismatch");
        assertEq(0, tBIC.balanceOf(creator), "Received amount fee mismatch");

        vm.startPrank(oneCPOwner);
        address[] memory blacklist;
        EmergencyPauseFacet(payable(address(oneCP))).unpauseDiamond(blacklist);

        vm.startPrank(caller);
        (actualGasCost, actualPayment) = ContentPaymentFacet(address(oneCP)).callBuyContent(
            buyAmount,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice,
            address(tBIC),
            buyer,
            creator,
            customerId,
            contentId
        );
        assertEq(actualGasCost * paymentPrice, actualPayment, "Gas Payment mismatch");
        assertEq((buyAmount * surchargeFee / 10_000) + actualPayment, tBIC.balanceOf(contentTreasury), "Surcharge fee mismatch");
        assertEq(buyAmount - (buyAmount * surchargeFee / 10_000), tBIC.balanceOf(creator), "Received amount fee mismatch");
    }
}