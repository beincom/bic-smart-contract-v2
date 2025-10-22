// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OneCPDiamond} from "../../src/1cp/1CPDiamond.sol";
import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {DonationFacet} from "../../src/1cp/facets/DonationFacet.sol";
import {AccessManagerFacet} from "../../src/diamond/facets/AccessManagerFacet.sol";
import {LibDiamond} from "../../src/diamond/libraries/LibDiamond.sol";

contract DonationFacetDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oneCP = vm.envAddress("ONE_CP");
        address donationPaymentToken = vm.envAddress("DONATION_PAYMENT_TOKEN");
        address donationTreasury = vm.envAddress("DONATION_TREASURY");
        address donationCaller = vm.envAddress("DONATION_CALLER");
        uint256 surchargeFee = vm.envUint("DONATION_SURCHARGE_FEE");
        uint256 bufferPostOp = vm.envUint("DONATION_BUFFER_POSTOP");

        vm.startBroadcast(deployerPrivateKey);

        // add donation facet
        addDonationFacet(oneCP);

        // update donation config
        DonationFacet(oneCP).initializeDonationConfig(
            donationTreasury,
            donationPaymentToken,
            surchargeFee,
            bufferPostOp    
        );
        
        // grant caller access to callDonation
        setAccessToSelector(oneCP, DonationFacet.callDonation.selector, donationCaller, true);

        vm.stopBroadcast();
    }

    function addDonationFacet(address oneCP) internal {
        DonationFacet donationFacet = new DonationFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](8);
        functionSelectors[0] = donationFacet.updateDonationTreasury.selector;
        functionSelectors[1] = donationFacet.updateDonationPaymentToken.selector;
        functionSelectors[2] = donationFacet.updateDonationSurchargeFee.selector;
        functionSelectors[3] = donationFacet.updateDonationBufferPostOp.selector;
        functionSelectors[4] = donationFacet.donate.selector;
        functionSelectors[5] = donationFacet.callDonation.selector;
        functionSelectors[6] = donationFacet.getDonationConfigStorage.selector;
        functionSelectors[7] = donationFacet.initializeDonationConfig.selector;

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