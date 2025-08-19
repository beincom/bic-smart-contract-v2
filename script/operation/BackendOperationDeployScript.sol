// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import "../../src/diamond/facets/AccessManagerFacet.sol";
import "../../src/diamond/facets/DiamondCutFacet.sol";
import "../../src/diamond/facets/DiamondLoupeFacet.sol";
import "../../src/diamond/facets/ERC1155ReceiverFacet.sol";
import "../../src/diamond/facets/OwnershipFacet.sol";
import "../../src/operation/BackendOperationDiamond.sol";
import "../../src/operation/facets/MinigameExchangeFacet.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";


contract BackendOperationDeployScript is Script {
    BackendOperationDiamond public diamond;
    DiamondCutFacet public diamondCutFacet;
    OwnershipFacet public ownershipFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    AccessManagerFacet public accessManagerFacet;
    ERC1155ReceiverFacet public erc1155ReceiverFacet;
    MinigameExchangeFacet public minigameExchangeFacet;
    address public diamondOwner;
    address public authorizedOperator;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
        diamondOwner = vm.envAddress("DIAMOND_OWNER");
        authorizedOperator = vm.envAddress("AUTHORIZED_OPERATOR");
        vm.startBroadcast(deployerPrivateKey);

        diamondCutFacet = new DiamondCutFacet();
        diamond = new BackendOperationDiamond(diamondOwner, address(diamondCutFacet));

        // Add core facets
        addOwnershipFacet();
        addDiamondLoupeFacet();
        addAccessManagerFacet();
        addERC1155ReceiverFacet();
        addMinigameExchangeFacet();

        AccessManagerFacet(address(diamond)).setCanExecute(
            MinigameExchangeFacet.transferNative.selector,
            authorizedOperator,
            true
        );
        AccessManagerFacet(address(diamond)).setCanExecute(
            MinigameExchangeFacet.transferERC20.selector,
            authorizedOperator,
            true
        );
        AccessManagerFacet(address(diamond)).setCanExecute(
            MinigameExchangeFacet.transferERC721.selector,
            authorizedOperator,
            true
        );
        AccessManagerFacet(address(diamond)).setCanExecute(
            MinigameExchangeFacet.transferERC1155.selector,
            authorizedOperator,
            true
        );
        AccessManagerFacet(address(diamond)).setCanExecute(
            MinigameExchangeFacet.transferERC1155Batch.selector,
            authorizedOperator,
            true
        );
        AccessManagerFacet(address(diamond)).setCanExecute(
            MinigameExchangeFacet.claimERC1155.selector,
            authorizedOperator,
            true
        );
        vm.stopBroadcast();
    }

    function addOwnershipFacet() internal {
        ownershipFacet = new OwnershipFacet();

        bytes4[] memory functionSelectors = new bytes4[](2);
        functionSelectors[0] = ownershipFacet.owner.selector;
        functionSelectors[1] = ownershipFacet.transferOwnership.selector;

        LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
        cut[0] = LibDiamond.FacetCut({
            facetAddress: address(ownershipFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        DiamondCutFacet(address(diamond)).diamondCut(cut, address(0), "");
    }

    function addDiamondLoupeFacet() internal {
        diamondLoupeFacet = new DiamondLoupeFacet();

        bytes4[] memory functionSelectors = new bytes4[](5);
        functionSelectors[0] = diamondLoupeFacet.facets.selector;
        functionSelectors[1] = diamondLoupeFacet.facetFunctionSelectors.selector;
        functionSelectors[2] = diamondLoupeFacet.facetAddresses.selector;
        functionSelectors[3] = diamondLoupeFacet.facetAddress.selector;
        functionSelectors[4] = diamondLoupeFacet.supportsInterface.selector;

        LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
        cut[0] = LibDiamond.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        DiamondCutFacet(address(diamond)).diamondCut(cut, address(0), "");
    }

    function addAccessManagerFacet() internal {
        accessManagerFacet = new AccessManagerFacet();

        bytes4[] memory functionSelectors = new bytes4[](2);
        functionSelectors[0] = accessManagerFacet.setCanExecute.selector;
        functionSelectors[1] = accessManagerFacet.addressCanExecuteMethod.selector;

        LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
        cut[0] = LibDiamond.FacetCut({
            facetAddress: address(accessManagerFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        DiamondCutFacet(address(diamond)).diamondCut(cut, address(0), "");
    }

    function addERC1155ReceiverFacet() internal {
        erc1155ReceiverFacet = new ERC1155ReceiverFacet();

        bytes4[] memory functionSelectors = new bytes4[](3);
        functionSelectors[0] = erc1155ReceiverFacet.onERC1155Received.selector;
        functionSelectors[1] = erc1155ReceiverFacet.onERC1155BatchReceived.selector;
        functionSelectors[2] = erc1155ReceiverFacet.initERC1155Receiver.selector;

        LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
        cut[0] = LibDiamond.FacetCut({
            facetAddress: address(erc1155ReceiverFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        // add facet and run initializer to set ERC165 support bits
        DiamondCutFacet(address(diamond)).diamondCut(
            cut,
            address(erc1155ReceiverFacet),
            abi.encodeWithSelector(erc1155ReceiverFacet.initERC1155Receiver.selector)
        );
    }

    function addMinigameExchangeFacet() internal {
        minigameExchangeFacet = new MinigameExchangeFacet();

        bytes4[] memory functionSelectors = new bytes4[](10);
        functionSelectors[0] = minigameExchangeFacet.transferNative.selector;
        functionSelectors[1] = minigameExchangeFacet.transferERC20.selector;
        functionSelectors[2] = minigameExchangeFacet.transferERC721.selector;
        functionSelectors[3] = minigameExchangeFacet.transferERC1155.selector;
        functionSelectors[4] = minigameExchangeFacet.transferERC1155Batch.selector;
        functionSelectors[5] = minigameExchangeFacet.getNativeBalance.selector;
        functionSelectors[6] = minigameExchangeFacet.getERC20Balance.selector;
        functionSelectors[7] = minigameExchangeFacet.ownsERC721.selector;
        functionSelectors[8] = minigameExchangeFacet.getERC1155Balance.selector;
        functionSelectors[9] = minigameExchangeFacet.claimERC1155.selector;

        LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
        cut[0] = LibDiamond.FacetCut({
            facetAddress: address(minigameExchangeFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        DiamondCutFacet(address(diamond)).diamondCut(cut, address(0), "");
    }

    function setAccessToSelector(
        bytes4 selector,
        address executor,
        bool canAccess
    ) internal {
        AccessManagerFacet(address(diamond)).setCanExecute(selector, executor, canAccess);
    }
}