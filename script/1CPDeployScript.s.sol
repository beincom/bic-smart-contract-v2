// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OneCPDiamond} from "../src/1cp/1CPDiamond.sol";
import {DiamondCutFacet} from "../src/1cp/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/1cp/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../src/1cp/facets/OwnershipFacet.sol";
import {AccessManagerFacet} from "../src/1cp/facets/AccessManagerFacet.sol";
import {EmergencyPauseFacet} from "../src/1cp/facets/EmergencyPauseFacet.sol";
import {LibDiamond} from "../src/1cp/libraries/LibDiamond.sol";

contract OneCPDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oneCPOwner = vm.envAddress("1CP_OWNER");
        vm.startBroadcast(deployerPrivateKey);

        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        console.log("DiamondCutFacet deployed at:", address(diamondCutFacet));



        vm.stopBroadcast();
    }

    // function addOwnershipFacet() internal {
    //     vm.startPrank(oneCPOwner);
    //     OwnershipFacet ownershipFacet = new OwnershipFacet();

    //     // prepare function selectors
    //     bytes4[] memory functionSelectors = new bytes4[](2);
    //     functionSelectors[0] = ownershipFacet.owner.selector;
    //     functionSelectors[1] = ownershipFacet.transferOwnership.selector;

    //     LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
    //     cut[0] = LibDiamond.FacetCut({
    //         facetAddress: address(ownershipFacet),
    //         action: LibDiamond.FacetCutAction.Add,
    //         functionSelectors: functionSelectors
    //     });
    //     // add facet
    //     DiamondCutFacet(address(oneCP)).diamondCut(cut, address(0), "");
    // }
}