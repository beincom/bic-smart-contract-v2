// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OneCPDiamond} from "../src/1cp/1CPDiamond.sol";
import {DiamondCutFacet} from "../src/1cp/facets/DiamondCutFacet.sol";
import {ContentPaymentFacet} from "../src/1cp/facets/ContentPaymentFacet.sol";
import {AccessManagerFacet} from "../src/1cp/facets/AccessManagerFacet.sol";
import {LibDiamond} from "../src/1cp/libraries/LibDiamond.sol";

contract ContentPaymentFacetUpdateConfigScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oneCP = vm.envAddress("ONE_CP");
        address paymentToken = 0x03c36763E271211961e9E42DC6D600F9cF0Ea417;
        address caller = 0xe450584F78be9DdeA56A535125Aa400F67BAbA36;

        vm.startBroadcast(deployerPrivateKey);

        // update content payment config
        ContentPaymentFacet(oneCP).updateContentPaymentToken(paymentToken);

        // grant caller access to callBuyContent
        setAccessToSelector(oneCP, ContentPaymentFacet.callBuyContent.selector, caller, true);

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