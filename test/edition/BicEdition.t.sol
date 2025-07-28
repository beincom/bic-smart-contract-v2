// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {BicEdition} from "src/edition/BicEdition.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDrop1155} from "src/extension/interface/IDrop1155.sol";
import {IClaimCondition} from "src/extension/interface/IClaimCondition.sol";

contract MockERC20 is IERC20 {
    string public constant name = "MockToken";
    string public constant symbol = "MTK";
    uint8 public constant decimals = 18;
    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    function transfer(address to, uint256 amount) external override returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient");
        require(allowance[from][msg.sender] >= amount, "Not allowed");
        balanceOf[from] -= amount;
        allowance[from][msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}

contract BicEditionTest is Test {
    BicEdition public edition;
    address public owner = address(0xABCD);
    address public user = address(0xBEEF);
    address public recipient = address(0xCAFE);
    MockERC20 public erc20;

    function setUp() public {
        erc20 = new MockERC20();
        edition = new BicEdition("BicEdition","E-BIC","https://base.uri/", owner, recipient);
        vm.prank(owner);
        edition.setMaxTotalSupply(1, 100);
    }

    function testOwnerCanSetPrimarySaleRecipient() public {
        vm.prank(owner);
        edition.setPrimarySaleRecipient(user);
        assertEq(edition.primarySaleRecipient(), user);
    }

    function testNonOwnerCannotSetPrimarySaleRecipient() public {
        vm.expectRevert();
        edition.setPrimarySaleRecipient(user);
    }

    function testOwnerCanSetMaxTotalSupply() public {
        vm.prank(owner);
        edition.setMaxTotalSupply(2, 50);
        assertEq(edition.maxTotalSupply(2), 50);
    }

    function testNonOwnerCannotSetMaxTotalSupply() public {
        vm.expectRevert();
        edition.setMaxTotalSupply(2, 50);
    }

    function testOwnerMintWithinMaxSupply() public {
        vm.prank(owner);
        edition.ownerMint(user, 1, 10);
        assertEq(edition.totalSupply(1), 10);
        assertEq(edition.balanceOf(user, 1), 10);
    }

    function testOwnerMintExceedsMaxSupplyReverts() public {
        vm.prank(owner);
        edition.ownerMint(user, 1, 100);
        vm.prank(owner);
        vm.expectRevert();
        edition.ownerMint(user, 1, 1);
    }

    function testOwnerMintBatchWithinMaxSupply() public {
        vm.prank(owner);
        edition.setMaxTotalSupply(2, 50);
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1; ids[1] = 2;
        amounts[0] = 10; amounts[1] = 20;
        vm.prank(owner);
        edition.ownerMintBatch(user, ids, amounts);
        assertEq(edition.totalSupply(1), 10);
        assertEq(edition.totalSupply(2), 20);
    }

    function testOwnerMintBatchExceedsMaxSupplyReverts() public {
        vm.prank(owner);
        edition.setMaxTotalSupply(2, 15);
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1; ids[1] = 2;
        amounts[0] = 10; amounts[1] = 20;
        vm.prank(owner);
        vm.expectRevert();
        edition.ownerMintBatch(user, ids, amounts);
    }

    function testSetCondtionAndClaim() public {
        vm.prank(owner);
        IClaimCondition.ClaimCondition[] memory conditions = new IClaimCondition.ClaimCondition[](1);
        conditions[0] = IClaimCondition.ClaimCondition({
            startTimestamp: block.timestamp,
            maxClaimableSupply: 100,
            supplyClaimed: 0,
            pricePerToken: 1000000000000000000,
            currency: address(erc20),
            merkleRoot: bytes32(0),
            quantityLimitPerWallet: 99,
            metadata: ""
        });
        edition.setClaimConditions(
            1,
            conditions,
            false
        );
        erc20.mint(user, 10000000000000000000);

        vm.startPrank(user);
        erc20.approve(address(edition), 1000000000000000000);
        edition.claim(user, 1, 1, address(erc20), 1000000000000000000, IDrop1155.AllowlistProof({
            proof: new bytes32[](0),
            quantityLimitPerWallet: 1,
            pricePerToken: 1000000000000000000,
            currency: address(erc20)
        }), "");
        vm.stopPrank();

        assertEq(edition.balanceOf(user, 1), 1);
        assertEq(erc20.balanceOf(user), 9000000000000000000);
    }

    function testLazyMint() public {
        vm.startPrank(owner);
        edition.lazyMint(1, "https://example.com/lazy/metadata/1", "0x");
        assertEq(edition.tokenURI(0), "https://example.com/lazy/metadata/1");
        edition.lazyMint(2, "https://example.com/lazy/metadata/1", "0x");
        vm.stopPrank();
        assertEq(edition.tokenURI(1), "https://example.com/lazy/metadata/1");
        assertEq(edition.totalSupply(1), 0); // No tokens minted yet
        assertEq(edition.tokenURI(2), "https://example.com/lazy/metadata/1");
        assertEq(edition.totalSupply(2), 0); // No tokens minted yet

        // if not lazy mint then get uri https://base.uri/{TokenId}
        assertEq(edition.uri(5), "https://base.uri/5");
    }

} 