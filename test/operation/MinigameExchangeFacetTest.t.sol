// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {BackendOperationDiamond} from "../../src/operation/BackendOperationDiamond.sol";
import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {OwnershipFacet} from "../../src/diamond/facets/OwnershipFacet.sol";
import {AccessManagerFacet} from "../../src/diamond/facets/AccessManagerFacet.sol";
import {MinigameExchangeFacet} from "../../src/operation/facets/MinigameExchangeFacet.sol";
import {LibDiamond} from "../../src/diamond/libraries/LibDiamond.sol";
import {LibAccess} from "../../src/diamond/libraries/LibAccess.sol";
import {IDrop1155} from "../../src/extension/interface/IDrop1155.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {BackendOperationTestBase} from "./BackendOperationTestBase.t.sol";

// Mock Drop contract for testing
contract MockDrop1155 is ERC1155 {
    constructor() ERC1155("https://mock.uri/{id}") {}
    
    function claim(
        address receiver,
        uint256 tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        IDrop1155.AllowlistProof calldata allowlistProof,
        bytes memory data
    ) external payable {
        // Simple mock implementation - just mint the tokens
        _mint(receiver, tokenId, quantity, "");
    }
    
    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }
}

contract MinigameExchangeFacetTest is BackendOperationTestBase {
    MockDrop1155 public mockDrop;
    
    event MinigameRewardExchange(
        MinigameExchangeFacet.TokenType indexed tokenType,
        address indexed token,
        uint256 indexed tokenId,
        uint256 amount,
        address recipient,
        string message
    );

    function setUp() public override {
        super.setUp();
    }

    function test_claimERC1155_Success() public {
        uint256 tokenId = 1;
        uint256 quantity = 5;
        string memory message = "Minigame reward claim from drop";
        
        uint256 initialBalance = mockDrop.balanceOf(recipient, tokenId);
        
        IDrop1155.AllowlistProof memory proof = IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 10,
            pricePerToken: 0,
            currency: address(0)
        });
        
        vm.prank(authorizedOperator);
        vm.expectEmit(true, true, true, true);
        emit MinigameRewardExchange(
            MinigameExchangeFacet.TokenType.ERC1155,
            address(mockDrop),
            tokenId,
            quantity,
            recipient,
            message
        );
        
        MinigameExchangeFacet(address(diamond)).claimERC1155(
            address(mockDrop),
            recipient,
            tokenId,
            quantity,
            address(0), // currency
            0, // pricePerToken
            proof,
            "",
            message
        );
        
        assertEq(mockDrop.balanceOf(recipient, tokenId), initialBalance + quantity);
    }

    function test_claimERC1155_UnauthorizedReverts() public {
        address unauthorized = address(9999);
        
        IDrop1155.AllowlistProof memory proof = IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 10,
            pricePerToken: 0,
            currency: address(0)
        });
        
        vm.prank(unauthorized);
        vm.expectRevert(LibAccess.UnAuthorized.selector);
        MinigameExchangeFacet(address(diamond)).claimERC1155(
            address(mockDrop),
            recipient,
            1,
            5,
            address(0),
            0,
            proof,
            "",
            "test"
        );
    }

    function test_claimERC1155_InvalidDropContractReverts() public {
        IDrop1155.AllowlistProof memory proof = IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 10,
            pricePerToken: 0,
            currency: address(0)
        });
        
        vm.prank(authorizedOperator);
        vm.expectRevert(MinigameExchangeFacet.InvalidTokenAddress.selector);
        MinigameExchangeFacet(address(diamond)).claimERC1155(
            address(0), // invalid drop contract
            recipient,
            1,
            5,
            address(0),
            0,
            proof,
            "",
            "test"
        );
    }

    function test_claimERC1155_InvalidRecipientReverts() public {
        IDrop1155.AllowlistProof memory proof = IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 10,
            pricePerToken: 0,
            currency: address(0)
        });
        
        vm.prank(authorizedOperator);
        vm.expectRevert(MinigameExchangeFacet.InvalidRecipient.selector);
        MinigameExchangeFacet(address(diamond)).claimERC1155(
            address(mockDrop),
            address(0), // invalid recipient
            1,
            5,
            address(0),
            0,
            proof,
            "",
            "test"
        );
    }

    function test_claimERC1155_InvalidQuantityReverts() public {
        IDrop1155.AllowlistProof memory proof = IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 10,
            pricePerToken: 0,
            currency: address(0)
        });
        
        vm.prank(authorizedOperator);
        vm.expectRevert(MinigameExchangeFacet.InvalidAmount.selector);
        MinigameExchangeFacet(address(diamond)).claimERC1155(
            address(mockDrop),
            recipient,
            1,
            0, // invalid quantity
            address(0),
            0,
            proof,
            "",
            "test"
        );
    }

    function test_claimERC1155_WithEtherPayment() public {
        uint256 tokenId = 2;
        uint256 quantity = 3;
        uint256 paymentAmount = 0.1 ether;
        string memory message = "Paid minigame reward claim";
        
        // Fund the diamond with ether for payment
        vm.deal(address(diamond), 1 ether);
        // Fund the test caller with ether to send with the transaction
        vm.deal(authorizedOperator, 1 ether);
        
        IDrop1155.AllowlistProof memory proof = IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 10,
            pricePerToken: paymentAmount / quantity,
            currency: address(0)
        });
        
        vm.startPrank(authorizedOperator);
        vm.expectEmit(true, true, true, true);
        emit MinigameRewardExchange(
            MinigameExchangeFacet.TokenType.ERC1155,
            address(mockDrop),
            tokenId,
            quantity,
            recipient,
            message
        );
        
        MinigameExchangeFacet(address(diamond)).claimERC1155{value: paymentAmount}(
            address(mockDrop),
            recipient,
            tokenId,
            quantity,
            address(0),
            paymentAmount / quantity,
            proof,
            "",
            message
        );
        vm.stopPrank();
        
        assertEq(mockDrop.balanceOf(recipient, tokenId), quantity);
    }


    function test_transferNative_UnauthorizedReverts() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert(LibAccess.UnAuthorized.selector);
        MinigameExchangeFacet(address(diamond)).transferNative(recipient, 1 ether, "test");
    }

    function test_transferNative_InvalidRecipientReverts() public {
        vm.prank(authorizedOperator);
        vm.expectRevert(MinigameExchangeFacet.InvalidRecipient.selector);
        MinigameExchangeFacet(address(diamond)).transferNative(address(0), 1 ether, "test");
    }

    function test_transferNative_InvalidAmountReverts() public {
        vm.prank(authorizedOperator);
        vm.expectRevert(MinigameExchangeFacet.InvalidAmount.selector);
        MinigameExchangeFacet(address(diamond)).transferNative(recipient, 0, "test");
    }

    function test_transferNative_InsufficientBalanceReverts() public {
        vm.prank(authorizedOperator);
        vm.expectRevert(MinigameExchangeFacet.InsufficientNativeBalance.selector);
        MinigameExchangeFacet(address(diamond)).transferNative(recipient, 100 ether, "test");
    }

    // ERC20 Token Transfer Tests
    function test_transferERC20_Success() public {
        uint256 transferAmount = 100e18;
        string memory message = "ERC20 reward for daily login";

        uint256 initialRecipientBalance = mockERC20.balanceOf(recipient);
        uint256 initialDiamondBalance = mockERC20.balanceOf(address(diamond));

        vm.prank(authorizedOperator);
        vm.expectEmit(true, true, true, true);
        emit MinigameRewardExchange(
            MinigameExchangeFacet.TokenType.ERC20,
            address(mockERC20),
            0,
            transferAmount,
            recipient,
            message
        );

        MinigameExchangeFacet(address(diamond)).transferERC20(
            address(mockERC20),
            recipient,
            transferAmount,
            message
        );

        assertEq(mockERC20.balanceOf(recipient), initialRecipientBalance + transferAmount);
        assertEq(mockERC20.balanceOf(address(diamond)), initialDiamondBalance - transferAmount);
    }

    function test_transferERC20_UnauthorizedReverts() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert(LibAccess.UnAuthorized.selector);
        MinigameExchangeFacet(address(diamond)).transferERC20(
            address(mockERC20),
            recipient,
            100e18,
            "test"
        );
    }

    function test_transferERC20_InvalidTokenReverts() public {
        vm.prank(authorizedOperator);
        vm.expectRevert(MinigameExchangeFacet.InvalidTokenAddress.selector);
        MinigameExchangeFacet(address(diamond)).transferERC20(address(0), recipient, 100e18, "test");
    }

    // ERC721 Token Transfer Tests
    function test_transferERC721_Success() public {
        uint256 tokenId = 1; // First minted token
        string memory message = "Rare NFT reward for tournament win";

        assertTrue(MinigameExchangeFacet(address(diamond)).ownsERC721(address(mockERC721), tokenId));

        vm.prank(authorizedOperator);
        vm.expectEmit(true, true, true, true);
        emit MinigameRewardExchange(
            MinigameExchangeFacet.TokenType.ERC721,
            address(mockERC721),
            tokenId,
            1,
            recipient,
            message
        );

        MinigameExchangeFacet(address(diamond)).transferERC721(
            address(mockERC721),
            recipient,
            tokenId,
            message
        );

        assertEq(mockERC721.ownerOf(tokenId), recipient);
        assertFalse(MinigameExchangeFacet(address(diamond)).ownsERC721(address(mockERC721), tokenId));
    }

    function test_transferERC721_UnauthorizedReverts() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert(LibAccess.UnAuthorized.selector);
        MinigameExchangeFacet(address(diamond)).transferERC721(
            address(mockERC721),
            recipient,
            1,
            "test"
        );
    }

    // ERC1155 Token Transfer Tests
    function test_transferERC1155_Success() public {
        uint256 tokenId = 1;
        uint256 transferAmount = 50;
        string memory message = "Multi-token reward";

        uint256 initialRecipientBalance = mockERC1155.balanceOf(recipient, tokenId);
        uint256 initialDiamondBalance = MinigameExchangeFacet(address(diamond)).getERC1155Balance(
            address(mockERC1155),
            tokenId
        );

        vm.prank(authorizedOperator);
        vm.expectEmit(true, true, true, true);
        emit MinigameRewardExchange(
            MinigameExchangeFacet.TokenType.ERC1155,
            address(mockERC1155),
            tokenId,
            transferAmount,
            recipient,
            message
        );

        MinigameExchangeFacet(address(diamond)).transferERC1155(
            address(mockERC1155),
            recipient,
            tokenId,
            transferAmount,
            message
        );

        assertEq(mockERC1155.balanceOf(recipient, tokenId), initialRecipientBalance + transferAmount);
        assertEq(
            MinigameExchangeFacet(address(diamond)).getERC1155Balance(address(mockERC1155), tokenId),
            initialDiamondBalance - transferAmount
        );
    }

    function test_transferERC1155Batch_Success() public {
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        amounts[0] = 30;
        amounts[1] = 40;
        string memory message = "Batch reward for special event";

        uint256[] memory initialRecipientBalances = new uint256[](2);
        uint256[] memory initialDiamondBalances = new uint256[](2);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            initialRecipientBalances[i] = mockERC1155.balanceOf(recipient, tokenIds[i]);
            initialDiamondBalances[i] = MinigameExchangeFacet(address(diamond)).getERC1155Balance(
                address(mockERC1155),
                tokenIds[i]
            );
        }

        vm.prank(authorizedOperator);
        // Expect events for each token in the batch
        for (uint256 i = 0; i < tokenIds.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit MinigameRewardExchange(
                MinigameExchangeFacet.TokenType.ERC1155,
                address(mockERC1155),
                tokenIds[i],
                amounts[i],
                recipient,
                message
            );
        }

        MinigameExchangeFacet(address(diamond)).transferERC1155Batch(
            address(mockERC1155),
            recipient,
            tokenIds,
            amounts,
            message
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(
                mockERC1155.balanceOf(recipient, tokenIds[i]),
                initialRecipientBalances[i] + amounts[i]
            );
            assertEq(
                MinigameExchangeFacet(address(diamond)).getERC1155Balance(address(mockERC1155), tokenIds[i]),
                initialDiamondBalances[i] - amounts[i]
            );
        }
    }

    function test_transferERC1155Batch_UnauthorizedReverts() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenIds[0] = 1;
        amounts[0] = 30;

        vm.prank(unauthorizedUser);
        vm.expectRevert(LibAccess.UnAuthorized.selector);
        MinigameExchangeFacet(address(diamond)).transferERC1155Batch(
            address(mockERC1155),
            recipient,
            tokenIds,
            amounts,
            "test"
        );
    }

    function test_transferERC1155Batch_MismatchedArraysRevert() public {
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](1); // Mismatched length
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        amounts[0] = 30;

        vm.prank(authorizedOperator);
        vm.expectRevert(MinigameExchangeFacet.InvalidAmount.selector);
        MinigameExchangeFacet(address(diamond)).transferERC1155Batch(
            address(mockERC1155),
            recipient,
            tokenIds,
            amounts,
            "test"
        );
    }

}
