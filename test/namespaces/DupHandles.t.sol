pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {DupHandles} from "../../src/namespaces/DupHandles.sol";

contract DupHandlesTest is Test {
    DupHandles public dupHandles;

    function setUp() public {
        dupHandles = new DupHandles();
        dupHandles.initialize("dup", "DUP", "DUP", address(this));
        dupHandles.setController(address(this));
    }

    function test_getAndMintDuplicateHandle() public {
        string memory localName = "test";

        uint256 supply = dupHandles.getSupplyOfLocalName(localName);
        assertEq(supply, 0);

        uint256 tokenId = dupHandles.getTokenIdByIndex(localName, 0);
        console.log("tokenId", tokenId);
        console.logBytes32(bytes32(tokenId));

        uint256 tokenId2 = dupHandles.getTokenIdByIndex(localName, 1);
        console.log("tokenId2", tokenId2);
        console.logBytes32(bytes32(tokenId2));

        uint256 tokenId3 = dupHandles.getTokenIdByIndex(localName, 2);
        console.log("tokenId3", tokenId3);
        console.logBytes32(bytes32(tokenId3));


        dupHandles.mintHandle(address(this), localName);
        dupHandles.mintHandle(address(this), localName);
        dupHandles.mintHandle(address(this), localName);

        supply = dupHandles.getSupplyOfLocalName(localName);

        assertEq(dupHandles.ownerOf(tokenId), address(this));
        assertEq(dupHandles.ownerOf(tokenId2), address(this));
        assertEq(dupHandles.ownerOf(tokenId3), address(this));
        assertEq(supply, 3);
    }

    function test_getAllOwners() public {
        string memory localName = "test";
        address owner1 = address(0x123123);
        address owner2 = address(0x123133);
        address owner3 = address(0x124123);

        dupHandles.mintHandle(owner1, localName);
        dupHandles.mintHandle(owner2, localName);
        dupHandles.mintHandle(owner3, localName);

        address[] memory allOwners = dupHandles.getAllOwnersOfLocalName(localName);
        assertEq(allOwners[0], owner1);
        assertEq(allOwners[1], owner2);
        assertEq(allOwners[2], owner3);
    }
}

