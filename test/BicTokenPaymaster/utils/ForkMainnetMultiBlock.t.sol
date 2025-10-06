// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {BicMultiBlock} from "../../../src/utils/MultiBlock.sol";
import {BicTokenPaymaster} from "../../../src/BicTokenPaymaster.sol";

/**
 * @title ForkMainnetMultiBlockTest
 * @notice Test suite for MultiBlock contract on forked Arbitrum mainnet
 * @dev Forks Arbitrum mainnet, deploys MultiBlock, mocks ownership transfer, and tests multiBlock functionality
 */
contract ForkMainnetMultiBlockTest is Test {
    // Arbitrum Mainnet addresses
    address constant BIC_TOKEN_PAYMASTER = 0xB1C3960aeeAf4C255A877da04b06487BBa698386;
    address constant ORIGINAL_OWNER = 0xb99f671B24B8E1dA7a67EfbdB0B627BEF9068c65;

    address constant MULTI_BLOCK_CONTRACT = 0x61f654Ba9E565849Eefa0dc02780233BdEC2213f;
    address constant MULTI_BLOCK_OWNER = 0xb99f671B24B8E1dA7a67EfbdB0B627BEF9068c65;
    
    // Test addresses to block
    address constant TEST_ADDRESS_1 = 0x1111111111111111111111111111111111111111;
    address constant TEST_ADDRESS_2 = 0x2222222222222222222222222222222222222222;
    address constant TEST_ADDRESS_3 = 0x3333333333333333333333333333333333333333;
    
    // Contract instances
    BicTokenPaymaster public bicToken;
    BicMultiBlock public multiBlock;
    
    // Events for testing
    event UpdateBic(address newBic);
    event TransferBicOwner(address executor, address newBicOwner);
    event MultiBlock(address[] addresses);
    event MultiUnblock(address[] addresses);
    event BlockUpdated(address indexed updater, address indexed addr, bool status);
    
    function setUp() public {
        // Fork Arbitrum mainnet
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        vm.createSelectFork(ARBITRUM_RPC_URL);
        
        // Get BicTokenPaymaster instance
        bicToken = BicTokenPaymaster(payable(BIC_TOKEN_PAYMASTER));
        
        // Deploy MultiBlock contract with original owner and BIC token
        multiBlock = BicMultiBlock(MULTI_BLOCK_CONTRACT);
        
        // Verify initial state
        assertEq(multiBlock.owner(), MULTI_BLOCK_OWNER, "MultiBlock owner should be MULTI_BLOCK_OWNER");
        assertEq(multiBlock.bic(), BIC_TOKEN_PAYMASTER, "MultiBlock bic should be BIC_TOKEN_PAYMASTER");
        assertEq(bicToken.owner(), ORIGINAL_OWNER, "BicToken owner should be ORIGINAL_OWNER");
    }
    
    /**
     * @notice Test complete flow: deploy MultiBlock, transfer ownership, block addresses, and transfer back
     * @dev Tests the entire workflow with state verification at each step
     */
    function test_ForkMainnet_CompleteMultiBlockFlow() public {
        // Prepare test addresses
        address[] memory addressesToBlock = new address[](3);
        addressesToBlock[0] = TEST_ADDRESS_1;
        addressesToBlock[1] = TEST_ADDRESS_2;
        addressesToBlock[2] = TEST_ADDRESS_3;
        
        // ========== STEP 1: Verify initial state ==========
        console.log("\n========== STEP 1: Initial State ==========");
        assertEq(bicToken.owner(), ORIGINAL_OWNER, "Initial: BicToken owner should be ORIGINAL_OWNER");
        assertEq(multiBlock.owner(), MULTI_BLOCK_OWNER, "Initial: MultiBlock owner should be MULTI_BLOCK_OWNER");
        assertEq(bicToken.isBlocked(TEST_ADDRESS_1), false, "Initial: TEST_ADDRESS_1 should not be blocked");
        assertEq(bicToken.isBlocked(TEST_ADDRESS_2), false, "Initial: TEST_ADDRESS_2 should not be blocked");
        assertEq(bicToken.isBlocked(TEST_ADDRESS_3), false, "Initial: TEST_ADDRESS_3 should not be blocked");
        console.log("BicToken owner:", bicToken.owner());
        console.log("MultiBlock owner:", multiBlock.owner());
        console.log("All addresses are unblocked");
        
        // ========== STEP 2: Mock ownership and transfer BicToken to MultiBlock ==========
        console.log("\n========== STEP 2: Transfer Ownership to MultiBlock ==========");
        
        // Mock the original owner
        vm.startPrank(ORIGINAL_OWNER);
        
        // Transfer BicToken ownership to MultiBlock
        bicToken.transferOwnership(address(multiBlock));
        
        // Verify ownership transfer
        assertEq(bicToken.owner(), address(multiBlock), "After transfer: BicToken owner should be MultiBlock");
        console.log("BicToken ownership transferred to MultiBlock:", bicToken.owner());
        
        vm.stopPrank();
        
        // ========== STEP 3: Call multiBlock to block 3 addresses ==========
        console.log("\n========== STEP 3: Block Multiple Addresses ==========");
        
        vm.startPrank(MULTI_BLOCK_OWNER);
        
        // Expect BlockUpdated events for each address (emitted during loop)
        vm.expectEmit(true, true, true, true, address(bicToken));
        emit BlockUpdated(address(multiBlock), TEST_ADDRESS_1, true);
        
        vm.expectEmit(true, true, true, true, address(bicToken));
        emit BlockUpdated(address(multiBlock), TEST_ADDRESS_2, true);
        
        vm.expectEmit(true, true, true, true, address(bicToken));
        emit BlockUpdated(address(multiBlock), TEST_ADDRESS_3, true);
        
        // Expect MultiBlock event (emitted after the loop)
        vm.expectEmit(true, true, true, true, address(multiBlock));
        emit MultiBlock(addressesToBlock);
        
        // Call multiBlock function
        multiBlock.multiBlock(addressesToBlock);
        
        // Verify all addresses are blocked
        assertEq(bicToken.isBlocked(TEST_ADDRESS_1), true, "After multiBlock: TEST_ADDRESS_1 should be blocked");
        assertEq(bicToken.isBlocked(TEST_ADDRESS_2), true, "After multiBlock: TEST_ADDRESS_2 should be blocked");
        assertEq(bicToken.isBlocked(TEST_ADDRESS_3), true, "After multiBlock: TEST_ADDRESS_3 should be blocked");
        console.log("TEST_ADDRESS_1 blocked:", bicToken.isBlocked(TEST_ADDRESS_1));
        console.log("TEST_ADDRESS_2 blocked:", bicToken.isBlocked(TEST_ADDRESS_2));
        console.log("TEST_ADDRESS_3 blocked:", bicToken.isBlocked(TEST_ADDRESS_3));
        
        vm.stopPrank();
        
        // ========== STEP 4: Transfer ownership back to original owner ==========
        console.log("\n========== STEP 4: Transfer Ownership Back to Original Owner ==========");
        
        vm.startPrank(MULTI_BLOCK_OWNER);
        
        // Expect TransferBicOwner event
        vm.expectEmit(true, true, true, true, address(multiBlock));
        emit TransferBicOwner(MULTI_BLOCK_OWNER, ORIGINAL_OWNER);
        
        // Transfer BicToken ownership back to original owner
        multiBlock.transferBicOwner(ORIGINAL_OWNER);
        
        // Verify ownership is back to original owner
        assertEq(bicToken.owner(), ORIGINAL_OWNER, "Final: BicToken owner should be ORIGINAL_OWNER");
        console.log("BicToken ownership transferred back to:", bicToken.owner());
        
        vm.stopPrank();
        
        // ========== STEP 5: Verify final state ==========
        console.log("\n========== STEP 5: Final State Verification ==========");
        assertEq(bicToken.owner(), ORIGINAL_OWNER, "Final: BicToken owner should be ORIGINAL_OWNER");
        assertEq(multiBlock.owner(), MULTI_BLOCK_OWNER, "Final: MultiBlock owner should be MULTI_BLOCK_OWNER");
        assertEq(bicToken.isBlocked(TEST_ADDRESS_1), true, "Final: TEST_ADDRESS_1 should remain blocked");
        assertEq(bicToken.isBlocked(TEST_ADDRESS_2), true, "Final: TEST_ADDRESS_2 should remain blocked");
        assertEq(bicToken.isBlocked(TEST_ADDRESS_3), true, "Final: TEST_ADDRESS_3 should remain blocked");
        console.log("BicToken owner:", bicToken.owner());
        console.log("MultiBlock owner:", multiBlock.owner());
        console.log("All addresses remain blocked");
        
        // ========== STEP 6: Verify MultiBlock can no longer call blockAddress ==========
        console.log("\n========== STEP 6: Verify MultiBlock Cannot Block After Ownership Transfer ==========");
        
        vm.startPrank(MULTI_BLOCK_OWNER);
        
        address[] memory newAddresses = new address[](1);
        newAddresses[0] = address(0x4444444444444444444444444444444444444444);
        
        // This should revert because MultiBlock is no longer the owner of BicToken
        vm.expectRevert();
        multiBlock.multiBlock(newAddresses);
        
        console.log("Verified: MultiBlock cannot block addresses after ownership transfer");
        
        vm.stopPrank();
        
        console.log("\n========== TEST COMPLETE ==========\n");
    }
}

