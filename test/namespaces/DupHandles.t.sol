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
        uint256 tokenId = dupHandles.getTokenId(localName, 0);
        console.log("tokenId", tokenId);
        console.logBytes32(bytes32(tokenId));

        uint256 tokenId2 = dupHandles.getTokenId(localName, 1);
        console.log("tokenId2", tokenId2);
        console.logBytes32(bytes32(tokenId2));

        dupHandles.mintHandle(address(this), localName);
        dupHandles.mintHandle(address(this), localName);

        assertEq(dupHandles.ownerOf(tokenId), address(this));
        assertEq(dupHandles.ownerOf(tokenId2), address(this));
    }
}

