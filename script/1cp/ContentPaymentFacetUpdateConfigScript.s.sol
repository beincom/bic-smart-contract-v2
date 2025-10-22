// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OneCPDiamond} from "../../src/1cp/1CPDiamond.sol";
import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {ContentPaymentFacet} from "../../src/1cp/facets/ContentPaymentFacet.sol";
import {AccessManagerFacet} from "../../src/diamond/facets/AccessManagerFacet.sol";
import {LibDiamond} from "../../src/diamond/libraries/LibDiamond.sol";

contract ContentPaymentFacetUpdateConfigScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oneCP = vm.envAddress("ONE_CP");
        address contentPaymentToken = vm.envAddress("CONTENT_PAYMENT_TOKEN");
        address contentCaller = vm.envAddress("CONTENT_CALLER");

        vm.startBroadcast(deployerPrivateKey);

        // update content payment config
        ContentPaymentFacet(oneCP).updateContentPaymentToken(contentPaymentToken);

        // grant caller access to callBuyContent
        setAccessToSelector(oneCP, ContentPaymentFacet.callBuyContent.selector, contentCaller, true);

        vm.stopBroadcast();
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