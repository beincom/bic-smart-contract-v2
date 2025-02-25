// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OneCPDiamond} from "../src/1cp/1CPDiamond.sol";
import {DiamondCutFacet} from "../src/1cp/facets/DiamondCutFacet.sol";
import {ContentPaymentFacet} from "../src/1cp/facets/ContentPaymentFacet.sol";
import {AccessManagerFacet} from "../src/1cp/facets/AccessManagerFacet.sol";
import {LibDiamond} from "../src/1cp/libraries/LibDiamond.sol";

contract ContentPaymentFacetDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oneCPOwner = vm.envAddress("ONECP_OWNER");
        address pauserWaller = vm.envAddress("PAUSER_WALLET");
        address oneCP = vm.envAddress("ONE_CP");
        address paymentToken = vm.envAddress("PAYMENT_TOKEN");
        address contentTreasury = vm.envAddress("CONTENT_TREASURY");
        address caller = vm.envAddress("CALLER");
        uint256 surchargeFee = 1000;
        uint256 bufferPostOp = 21000;

        vm.startBroadcast(deployerPrivateKey);

        // add content payment facet
        addContentPaymentFacet(oneCP);

        // update content payment config
        ContentPaymentFacet(oneCP).updateContentTreasury(contentTreasury);
        ContentPaymentFacet(oneCP).updateContentPaymentToken(paymentToken);
        ContentPaymentFacet(oneCP).updateContentSurchargeFee(surchargeFee);
        ContentPaymentFacet(oneCP).updateContentBufferPostOp(bufferPostOp);

        // grant caller access to callBuyContent
        setAccessToSelector(oneCP, ContentPaymentFacet.callBuyContent.selector, caller, true);

        vm.stopBroadcast();
    }

    function addContentPaymentFacet(address oneCP) internal {
        ContentPaymentFacet contentPaymentFacet = new ContentPaymentFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](6);
        functionSelectors[0] = contentPaymentFacet.updateContentTreasury.selector;
        functionSelectors[1] = contentPaymentFacet.updateContentPaymentToken.selector;
        functionSelectors[2] = contentPaymentFacet.updateContentSurchargeFee.selector;
        functionSelectors[3] = contentPaymentFacet.updateContentBufferPostOp.selector;
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