// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OneCPDiamond} from "../../src/1cp/1CPDiamond.sol";
import {DiamondCutFacet} from "../../src/1cp/facets/DiamondCutFacet.sol";
import {MiniGameFacet} from "../../src/1cp/facets/MiniGameFacet.sol";
import {AccessManagerFacet} from "../../src/1cp/facets/AccessManagerFacet.sol";
import {LibDiamond} from "../../src/1cp/libraries/LibDiamond.sol";

contract MiniGameFacetDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oneCP = vm.envAddress("ONE_CP");
        address miniGamePaymentToken = vm.envAddress("MINI_GAME_PAYMENT_TOKEN");
        address miniGameTreasury = vm.envAddress("MINI_GAME_TREASURY");
        address miniGameCaller = vm.envAddress("MINI_GAME_CALLER");
        address rewardPool = vm.envAddress("MINI_GAME_REWARD_POOL");
        uint256 rewardPercent = vm.envUint("MINI_GAME_REWARD_PERCENT");
        uint256 bufferPostOp = vm.envUint("MINI_GAME_BUFFER_POSTOP");

        vm.startBroadcast(deployerPrivateKey);

        // add mini game facet
        addMiniGameFacet(oneCP);

        // update mini game config
        MiniGameFacet(oneCP).initializeMiniGameConfig(
            bufferPostOp,
            rewardPercent,
            miniGameTreasury,
            rewardPool,
            miniGamePaymentToken
        );

        // grant caller access to callBuyToolPack
        setAccessToSelector(oneCP, MiniGameFacet.callBuyToolPack.selector, miniGameCaller, true);

        vm.stopBroadcast();
    }

    function addMiniGameFacet(address oneCP) internal {
        MiniGameFacet miniGameFacet = new MiniGameFacet();

        // prepare function selectors
        bytes4[] memory functionSelectors = new bytes4[](8);
        functionSelectors[0] = miniGameFacet.getMiniGameStorage.selector;
        functionSelectors[1] = miniGameFacet.initializeMiniGameConfig.selector;
        functionSelectors[2] = miniGameFacet.updateMiniGameTreasury.selector;
        functionSelectors[3] = miniGameFacet.updateMiniGamePaymentToken.selector;
        functionSelectors[4] = miniGameFacet.updateMiniGameBufferPostOp.selector;
        functionSelectors[5] = miniGameFacet.updateRewardConfig.selector;
        functionSelectors[6] = miniGameFacet.buyToolPack.selector;
        functionSelectors[7] = miniGameFacet.callBuyToolPack.selector;

        // prepare diamondCut
        LibDiamond.FacetCut[] memory cuts = new LibDiamond.FacetCut[](1);
        cuts[0] = LibDiamond.FacetCut({
            facetAddress: address(miniGameFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        // add mini game facet
        DiamondCutFacet(address(oneCP)).diamondCut(cuts, address(0), "");
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