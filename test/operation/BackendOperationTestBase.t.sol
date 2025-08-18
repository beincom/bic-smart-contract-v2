// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {BackendOperationDiamond} from "../../src/operation/BackendOperationDiamond.sol";
import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../../src/diamond/facets/OwnershipFacet.sol";
import {AccessManagerFacet} from "../../src/diamond/facets/AccessManagerFacet.sol";
import {MinigameExchangeFacet} from "../../src/operation/facets/MinigameExchangeFacet.sol";
import {LibDiamond} from "../../src/diamond/libraries/LibDiamond.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockERC721 is ERC721 {
    uint256 private _nextTokenId = 1;
    
    constructor() ERC721("Mock NFT", "MNFT") {}
    
    function mint(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        return tokenId;
    }
}

contract MockERC1155 is ERC1155 {
    constructor() ERC1155("https://mock.uri/{id}") {}
    
    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }
    
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external {
        _mintBatch(to, ids, amounts, "");
    }
}

contract BackendOperationTestBase is Test {
    BackendOperationDiamond public diamond;
    DiamondCutFacet public diamondCutFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public ownershipFacet;
    AccessManagerFacet public accessManagerFacet;
    MinigameExchangeFacet public minigameExchangeFacet;
    
    MockERC20 public mockERC20;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;
    
    address public diamondOwner;
    address public authorizedOperator;
    address public unauthorizedUser;
    address public recipient;

    function setUp() public virtual {
        diamondOwner = address(1234);
        authorizedOperator = address(5678);
        unauthorizedUser = address(9012);
        recipient = address(3456);
        
        // Deploy diamond with diamond cut facet
        diamondCutFacet = new DiamondCutFacet();
        diamond = new BackendOperationDiamond(diamondOwner, address(diamondCutFacet));
        
        // Add core facets
        addOwnershipFacet();
        addDiamondLoupeFacet();
        addAccessManagerFacet();
        addMinigameExchangeFacet();
        
        // Deploy mock tokens
        mockERC20 = new MockERC20();
        mockERC721 = new MockERC721();
        mockERC1155 = new MockERC1155();
        
        // Set up access control for authorized operator
        vm.startPrank(diamondOwner);
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
        vm.stopPrank();
        
        // Fund diamond and mint tokens
        vm.deal(address(diamond), 10 ether);
        mockERC20.mint(address(diamond), 1000e18);
        mockERC721.mint(address(diamond));
        mockERC1155.mint(address(diamond), 1, 100);
        mockERC1155.mint(address(diamond), 2, 200);
    }

    function addOwnershipFacet() internal {
        vm.startPrank(diamondOwner);
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
        vm.stopPrank();
    }
    
    function addDiamondLoupeFacet() internal {
        vm.startPrank(diamondOwner);
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
        vm.stopPrank();
    }

    function addAccessManagerFacet() internal {
        vm.startPrank(diamondOwner);
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
        vm.stopPrank();
    }

    function addMinigameExchangeFacet() internal {
        vm.startPrank(diamondOwner);
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
        vm.stopPrank();
    }

    function setAccessToSelector(
        bytes4 selector,
        address executor,
        bool canAccess
    ) internal {
        vm.prank(diamondOwner);
        AccessManagerFacet(address(diamond)).setCanExecute(selector, executor, canAccess);
    }
}
