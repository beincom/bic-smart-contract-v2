// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OneCPDiamond} from "../../src/1cp/1CPDiamond.sol";
import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {LuckyWheelFacet} from "../../src/1cp/facets/LuckyWheelFacet.sol";
import {AccessManagerFacet} from "../../src/diamond/facets/AccessManagerFacet.sol";
import {LibDiamond} from "../../src/diamond/libraries/LibDiamond.sol";

contract LuckyWheelFacetDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oneCP = vm.envAddress("ONE_CP");
        address luckyWheelPaymentToken = vm.envAddress("LUCKY_WHEEL_PAYMENT_TOKEN");
        address luckyWheelTreasury = vm.envAddress("LUCKY_WHEEL_TREASURY");
        address luckyWheelCaller = vm.envAddress("LUCKY_WHEEL_CALLER");
        uint256 bufferPostOp = vm.envUint("LUCKY_WHEEL_BUFFER_POSTOP");

        vm.startBroadcast(deployerPrivateKey);

        // add lucky wheel facet
        addLuckyWheelFacet(oneCP);

        // update lucky wheel config
        LuckyWheelFacet(oneCP).initializeLuckyWheelConfig(
            luckyWheelTreasury,
            luckyWheelPaymentToken,
            bufferPostOp    
        );

        // grant caller access to callBuyLuckyWheel
        setAccessToSelector(oneCP, LuckyWheelFacet.callBuyLuckyWheel.selector, luckyWheelCaller, true);

        vm.stopBroadcast();
    }

    function addLuckyWheelFacet(address oneCP) internal {
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