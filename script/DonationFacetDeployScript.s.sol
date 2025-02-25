// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OneCPDiamond} from "../src/1cp/1CPDiamond.sol";
import {DiamondCutFacet} from "../src/1cp/facets/DiamondCutFacet.sol";
import {DonationFacet} from "../src/1cp/facets/DonationFacet.sol";
import {AccessManagerFacet} from "../src/1cp/facets/AccessManagerFacet.sol";
import {LibDiamond} from "../src/1cp/libraries/LibDiamond.sol";

contract DonationFacetDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oneCPOwner = vm.envAddress("ONECP_OWNER");
        address pauserWaller = vm.envAddress("PAUSER_WALLET");
        address oneCP = vm.envAddress("ONE_CP");
        address paymentToken = vm.envAddress("PAYMENT_TOKEN");
        address donationTreasury = vm.envAddress("DONATION_TREASURY");
        address caller = vm.envAddress("CALLER");
        uint256 surchargeFee = 1000;
        uint256 bufferPostOp = 21000;

        vm.startBroadcast(deployerPrivateKey);

        // add donation facet
        addDonationFacet(oneCP);

        // update donation config
        DonationFacet(oneCP).updateDonationTreasury(donationTreasury);
        DonationFacet(oneCP).updateDonationPaymentToken(paymentToken);
        DonationFacet(oneCP).updateDonationSurchargeFee(surchargeFee);
        DonationFacet(oneCP).updateDonationBufferPostOp(bufferPostOp);

        // grant caller access to callDonation
        setAccessToSelector(oneCP, DonationFacet.callDonation.selector, caller, true);

        vm.stopBroadcast();
    }

    function addDonationFacet(address oneCP) internal {
        DonationFacet donationFacet = new DonationFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](6);
        functionSelectors[0] = donationFacet.updateDonationTreasury.selector;
        functionSelectors[1] = donationFacet.updateDonationPaymentToken.selector;
        functionSelectors[2] = donationFacet.updateDonationSurchargeFee.selector;
        functionSelectors[3] = donationFacet.updateDonationBufferPostOp.selector;
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
        DiamondCutFacet(oneCP).diamondCut(cuts, address(0), "");
    }

    function setAccessToSelector(
        address oneCP,
        bytes4 selector,
        address executor,
        bool canAccess
    ) internal {
        AccessManagerFacet(oneCP).setCanExecute(selector, executor, canAccess);
    }
}