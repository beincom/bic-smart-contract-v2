// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OneCPDiamond} from "../src/1cp/1CPDiamond.sol";
import {DiamondCutFacet} from "../src/1cp/facets/DiamondCutFacet.sol";
import {UserPaymentFacet} from "../src/1cp/facets/UserPaymentFacet.sol";
import {AccessManagerFacet} from "../src/1cp/facets/AccessManagerFacet.sol";
import {LibDiamond} from "../src/1cp/libraries/LibDiamond.sol";

contract UserPaymentFacetDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oneCP = vm.envAddress("ONE_CP");
        address userPaymentToken = vm.envAddress("USER_PAYMENT_TOKEN");
        address userTreasury = vm.envAddress("USER_TREASURY");
        address userCaller = vm.envAddress("USER_CALLER");
        uint256 surchargeFee = 1000;
        uint256 bufferPostOp = 21000;

        vm.startBroadcast(deployerPrivateKey);

        // add user payment facet
        addUserPaymentFacet(oneCP);

        // update content payment config
        UserPaymentFacet(oneCP).initializeUserPaymentConfig(
            userTreasury,
            userPaymentToken,
            surchargeFee,
            bufferPostOp
        );
        
        // grant caller access to callBuyContent
        setAccessToSelector(oneCP, UserPaymentFacet.callBuyAccount.selector, userCaller, true);

        vm.stopBroadcast();
    }

    function addUserPaymentFacet(address oneCP) internal {
        UserPaymentFacet userPaymentFacet = new UserPaymentFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](8);
        functionSelectors[0] = userPaymentFacet.updateUserTreasury.selector;
        functionSelectors[1] = userPaymentFacet.updateUserPaymentToken.selector;
        functionSelectors[2] = userPaymentFacet.updateUserSurchargeFee.selector;
        functionSelectors[3] = userPaymentFacet.updateUserBufferPostOp.selector;
        functionSelectors[4] = userPaymentFacet.buyAccount.selector;
        functionSelectors[5] = userPaymentFacet.callBuyAccount.selector;
        functionSelectors[6] = userPaymentFacet.getUserPaymentStorage.selector;
        functionSelectors[7] = userPaymentFacet.initializeUserPaymentConfig.selector;

        // prepare diamondCut
        LibDiamond.FacetCut[] memory cuts = new LibDiamond.FacetCut[](1);
        cuts[0] = LibDiamond.FacetCut({
            facetAddress: address(userPaymentFacet),
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