// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OneCPTestBase} from "../1CPTestBase.t.sol";
import {AccessManagerTest} from "./AccessManagerFacet.t.sol";
import {DiamondCutFacet} from "../../../src/1cp/facets/DiamondCutFacet.sol";
import {DonationFacet} from "../../../src/1cp/facets/DonationFacet.sol";
import {LibDiamond} from "../../../src/1cp/libraries/LibDiamond.sol";

contract TestERC20 is ERC20 {
    constructor() ERC20("TestERC20", "TEST") {
        _mint(msg.sender, 1e24);
    }

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}

contract DonationFacetTest is AccessManagerTest {
    TestERC20 public tBIC;
    address public donator;
    address public receiver;
    address public caller;
    address public donationTreasury;
    uint256 public surchargeFee;
    uint256 public bufferPostOp;
    function setUp() public override virtual {
        super.setUp();
        vm.startPrank(oneCPOwner);
        donator = address(123456);
        receiver = address(12345678);
        caller = address(12345666);
        donationTreasury = address(1222);
        surchargeFee = 1000;
        bufferPostOp = 21000;
        tBIC = new TestERC20();
        DonationFacet donationFacet = new DonationFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](6);
        functionSelectors[0] = donationFacet.updateDonationTreasury.selector;
        functionSelectors[1] = donationFacet.updatePaymentToken.selector;
        functionSelectors[2] = donationFacet.updateSurchargeFee.selector;
        functionSelectors[3] = donationFacet.updateBufferPostOp.selector;
        functionSelectors[4] = donationFacet.donate.selector;
        functionSelectors[5] = donationFacet.callDonation.selector;

        // prepare diamondCut
        LibDiamond.FacetCut[] memory cuts = new LibDiamond.FacetCut[](1);
        cuts[0] = LibDiamond.FacetCut({
            facetAddress: address(donationFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        // add donation facet
        DiamondCutFacet(address(oneCP)).diamondCut(cuts, address(0), "");

        // update donation config
        DonationFacet(address(oneCP)).updateDonationTreasury(donationTreasury);
        DonationFacet(address(oneCP)).updatePaymentToken(address(tBIC));
        DonationFacet(address(oneCP)).updateSurchargeFee(surchargeFee);
        DonationFacet(address(oneCP)).updateBufferPostOp(bufferPostOp);

        // grant caller access to callDonation
        setAccessToSelector(donationFacet.callDonation.selector, caller, true); 
    }

    function test_donate() public {
        vm.startPrank(donator);
        uint256 donateAmount = 1e24;
        tBIC.mint(donateAmount);
        tBIC.approve(address(oneCP), donateAmount);
        DonationFacet(address(oneCP)).donate(
            address(tBIC),
            receiver,
            donateAmount,
            "donate"
        );
        assertEq(donateAmount * surchargeFee / 10_000, tBIC.balanceOf(donationTreasury), "Surcharge fee mismatch");
        assertEq(donateAmount - (donateAmount * surchargeFee / 10_000), tBIC.balanceOf(receiver), "Received amount fee mismatch");
    }

    function test_callDonation() public {
        vm.startPrank(donator);
        tBIC.mint(1e25);
        uint256 donateAmount = 1e24;
        uint256 maxFeePerGas = 1e9;
        uint256 maxPriorityFeePerGas = 1e8;
        uint256 paymentPrice = 1e6;
        tBIC.approve(address(oneCP), 1e25);
        vm.startPrank(caller);
        (uint256 actualGasCost, uint256 actualPayment) = DonationFacet(address(oneCP)).callDonation(
            donateAmount,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice,
            address(tBIC),
            donator,
            receiver,
            "donate"
        );
        assertEq(actualGasCost * paymentPrice, actualPayment, "Gas Payment mismatch");
        assertEq((donateAmount * surchargeFee / 10_000) + actualPayment, tBIC.balanceOf(donationTreasury), "Surcharge fee mismatch");
        assertEq(donateAmount - (donateAmount * surchargeFee / 10_000), tBIC.balanceOf(receiver), "Received amount fee mismatch");
    }

    function test_failed_callDonation() public {
        vm.startPrank(donator);
        tBIC.mint(1e25);
        uint256 donateAmount = 1e24;
        uint256 maxFeePerGas = 1e9;
        uint256 maxPriorityFeePerGas = 1e8;
        uint256 paymentPrice = 1e6;
        tBIC.approve(address(oneCP), 1e25);
        vm.startPrank(receiver);
        vm.expectRevert();
        (uint256 actualGasCost, uint256 actualPayment) = DonationFacet(address(oneCP)).callDonation(
            donateAmount,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymentPrice,
            address(tBIC),
            donator,
            receiver,
            "donate"
        );
        assertEq(0, tBIC.balanceOf(donationTreasury), "Surcharge fee mismatch");
        assertEq(0, tBIC.balanceOf(receiver), "Received amount fee mismatch");
    }
}