// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BicEdition} from "src/edition/BicEdition.sol";
import {ITokenBundle} from "src/extension/interface/ITokenBundle.sol";
import {PackSaleStore} from "src/pack/PackSaleStore.sol";
import {BicPack} from "src/pack/BicPack.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract BamzoDeployer is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
    address deployOwner = vm.addr(deployerPrivateKey);

    function run() external {

        address bic = vm.envAddress("BIC_ADDRESS_TESTNET");

        string memory bamzoUri = vm.envString("BAMZO_URI");
        address bamzoOwner = vm.envAddress("EDITION_OWNER_TESTNET");
        address bamzoTreasury = vm.envAddress("EDITION_TREASURY_TESTNET");

        string memory lootboxUri = vm.envString("LOOTBOX_URI");
        address lootboxOwner = vm.envAddress("LOOTBOX_OWNER_TESTNET");

        // address packStoreOperator = vm.envAddress("HANDLE_CONTROLLER_VERIFIER_ADDRESS");
        address packStoreOperator = vm.envAddress("PACK_STORE_OPERATOR_ADDRESS_TESTNET");

        vm.startBroadcast(deployerPrivateKey);
        // BicEdition bamzo = new BicEdition(
        //     "Original Bamzo",
        //     "OGBZ",
        //     bamzoUri,
        //     deployOwner,
        //     bamzoTreasury
        // );

        // BicPack lootbox = new BicPack(
        //     "Dev - Original Bamzo Lootbox",
        //     "dev - OGBZLB",
        //     lootboxUri,
        //     deployOwner
        // );
        // IERC20(bic).approve(
        //     address(lootbox),
        //     21645 ether
        // );
        // bamzo.setApprovalForAll(address(lootbox), true);

        // mintBamzoAndCreateLootbox(bic, bamzo, lootbox);

        BicPack lootbox = BicPack(vm.envAddress("LOOTBOX_ADDRESS_TESTNET"));
        createPackStore(bic, lootbox, packStoreOperator);

        // transferOwnership(bamzo, bamzoOwner, lootbox, lootboxOwner);

        vm.stopBroadcast();

    }

    function mintBamzoAndCreateLootbox(address bic, BicEdition bamzo, BicPack lootbox) internal {
        uint256[] memory ids = new uint256[](46);
        uint256[] memory amounts = new uint256[](46);
        ids[0] = 0;    amounts[0] = 375;
        ids[1] = 1;    amounts[1] = 376;
        ids[2] = 2;    amounts[2] = 376;
        ids[3] = 3;    amounts[3] = 376;
        ids[4] = 4;    amounts[4] = 376;

        ids[5] = 5;    amounts[5] = 124;
        ids[6] = 6;    amounts[6] = 125;
        ids[7] = 7;    amounts[7] = 125;
        ids[8] = 8;    amounts[8] = 125;
        ids[9] = 9;    amounts[9] = 125;
        ids[10] = 10;  amounts[10] = 125;
        ids[11] = 11;  amounts[11] = 125;
        ids[12] = 12;  amounts[12] = 125;

        ids[13] = 13;  amounts[13] = 30;
        ids[14] = 14;  amounts[14] = 30;
        ids[15] = 15;  amounts[15] = 30;
        ids[16] = 16;  amounts[16] = 30;
        ids[17] = 17;  amounts[17] = 30;
        ids[18] = 18;  amounts[18] = 30;
        ids[19] = 19;  amounts[19] = 30;
        ids[20] = 20;  amounts[20] = 30;
        ids[21] = 21;  amounts[21] = 31;
        ids[22] = 22;  amounts[22] = 31;
        ids[23] = 23;  amounts[23] = 31;

        ids[24] = 24;  amounts[24] = 10;
        ids[25] = 25;  amounts[25] = 10;
        ids[26] = 26;  amounts[26] = 10;
        ids[27] = 27;  amounts[27] = 10;
        ids[28] = 28;  amounts[28] = 10;
        ids[29] = 29;  amounts[29] = 10;
        ids[30] = 30;  amounts[30] = 10;
        ids[31] = 31;  amounts[31] = 10;
        ids[32] = 32;  amounts[32] = 10;
        ids[33] = 33;  amounts[33] = 10;
        ids[34] = 34;  amounts[34] = 11;

        ids[35] = 35;  amounts[35] = 1;
        ids[36] = 36;  amounts[36] = 1;
        ids[37] = 37;  amounts[37] = 1;
        ids[38] = 38;  amounts[38] = 1;
        ids[39] = 39;  amounts[39] = 1;
        ids[40] = 40;  amounts[40] = 1;
        ids[41] = 41;  amounts[41] = 1;
        ids[42] = 42;  amounts[42] = 1;
        ids[43] = 43;  amounts[43] = 1;
        ids[44] = 44;  amounts[44] = 1;
        ids[45] = 45;  amounts[45] = 1;

        bamzo.ownerMintBatch(deployOwner, ids, amounts);
        
        // Create freeBox
        {
            ITokenBundle.Token[] memory freeBoxContents = new ITokenBundle.Token[](25);
            uint256[] memory freeBoxNumOfRewardUnits = new uint256[](25);

            // Token 0: bic (ERC20)
            freeBoxContents[0] = ITokenBundle.Token(
                address(bic), 
                ITokenBundle.TokenType.ERC20, 
                0, 
                21645 ether
            );
            freeBoxNumOfRewardUnits[0] = 555;

            // Tokens 1-45: bamzo (ERC1155), only nonzero amounts
            uint256 idx = 1;
            uint256[46] memory freeBoxRewardUnits = [
                uint256(55), uint256(55), uint256(54), uint256(54), uint256(54), // 0-4
                6,7,7,6,6,6,6,6, // 5-12
                1,1,1,1,1,1,1,1,1, // 13-21
                0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0 // 22-45
            ];
            for (uint256 i = 0; i < 46; i++) {
                if (freeBoxRewardUnits[i] > 0) {
                    freeBoxContents[idx] = ITokenBundle.Token(
                        address(bamzo),
                        ITokenBundle.TokenType.ERC1155,
                        i,
                        freeBoxRewardUnits[i]
                    );
                    freeBoxNumOfRewardUnits[idx] = freeBoxRewardUnits[i];
                    idx++;
                }
            }

            (uint256 freeBoxPackId, uint256 freeBoxPackTotalSupply) = lootbox.createPack(
                freeBoxContents,
                freeBoxNumOfRewardUnits,
                "https://pack.uri/freeBox",
                uint128(block.timestamp),
                uint128(1),
                deployOwner
            );

            console.log("freeBox pack ID:", freeBoxPackId);
            console.log("freeBox pack total supply:", freeBoxPackTotalSupply);
        }

        // Create silverBox
        {
            ITokenBundle.Token[] memory silverBoxContents = new ITokenBundle.Token[](27);
            uint256[] memory silverBoxNumOfRewardUnits = new uint256[](27);

            // Only OGBZ tokens with non-zero Total Supply
            uint256[46] memory silverBoxRewardUnits = [
                uint256(117), uint256(118), uint256(118), uint256(118), uint256(118), // 0-4
                36,36,36,37,37,37,37,37, // 5-12
                2,2,2,2,1,1,1,1,1,1,1, // 13-23
                0,1,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0 // 24-45
            ];
            uint256 idx = 0;
            for (uint256 i = 0; i < 46; i++) {
                if (silverBoxRewardUnits[i] > 0) {
                    silverBoxContents[idx] = ITokenBundle.Token(
                        address(bamzo),
                        ITokenBundle.TokenType.ERC1155,
                        i,
                        silverBoxRewardUnits[i]
                    );
                    silverBoxNumOfRewardUnits[idx] = silverBoxRewardUnits[i];
                    idx++;
                }
            }

            (uint256 silverBoxPackId, uint256 silverBoxPackTotalSupply) = lootbox.createPack(
                silverBoxContents,
                silverBoxNumOfRewardUnits,
                "https://pack.uri/silverBox",
                uint128(block.timestamp),
                uint128(1),
                deployOwner
            );

            console.log("silverBox pack ID:", silverBoxPackId);
            console.log("silverBox pack total supply:", silverBoxPackTotalSupply);
        }

        // Create goldBox (temporarily commented out)
        {
            ITokenBundle.Token[] memory goldBoxContents = new ITokenBundle.Token[](38);
            uint256[] memory goldBoxNumOfRewardUnits = new uint256[](38);

            // Only OGBZ tokens with non-zero Total Supply
            uint256[46] memory goldBoxRewardUnits = [
                uint256(126), uint256(126), uint256(126), uint256(126), uint256(126), // 0-4
                60,60,60,61,61,61,61,61, // 5-12
                9,9,9,9,8,9,9,9,9,9,9, // 13-23
                3,3,3,3,3,3,3,3,3,3,4,0,0,1,1,1,0,0,0,0,0,0 // 24-45
            ];
            uint256 idx = 0;
            for (uint256 i = 0; i < 46; i++) {
                if (goldBoxRewardUnits[i] > 0) {
                    goldBoxContents[idx] = ITokenBundle.Token(
                        address(bamzo),
                        ITokenBundle.TokenType.ERC1155,
                        i,
                        goldBoxRewardUnits[i]
                    );
                    goldBoxNumOfRewardUnits[idx] = goldBoxRewardUnits[i];
                    idx++;
                }
            }

            (uint256 goldBoxPackId, uint256 goldBoxPackTotalSupply) = lootbox.createPack(
                goldBoxContents,
                goldBoxNumOfRewardUnits,
                "https://pack.uri/goldBox",
                uint128(block.timestamp),
                uint128(1),
                deployOwner
            );

            console.log("goldBox pack ID:", goldBoxPackId);
            console.log("goldBox pack total supply:", goldBoxPackTotalSupply);
        }

        // Create platinumBox
        {
            ITokenBundle.Token[] memory platinumBoxContents = new ITokenBundle.Token[](41);
            uint256[] memory platinumBoxNumOfRewardUnits = new uint256[](41);

            // Only OGBZ tokens with non-zero Total Supply
            uint256[46] memory platinumBoxRewardUnits = [
                uint256(77), uint256(77), uint256(78), uint256(78), uint256(78), // 0-4
                22,22,22,21,21,21,21,21, // 5-12
                18,18,18,18,20,19,19,19,20,21,21, // 13-23
                6,6,6,7,7,7,7,7,7,7,7,0,0,0,0,0,1,1,1,1,1,1 // 24-45
            ];
            uint256 idx = 0;
            for (uint256 i = 0; i < 46; i++) {
                if (platinumBoxRewardUnits[i] > 0) {
                    platinumBoxContents[idx] = ITokenBundle.Token(
                        address(bamzo),
                        ITokenBundle.TokenType.ERC1155,
                        i,
                        platinumBoxRewardUnits[i]
                    );
                    platinumBoxNumOfRewardUnits[idx] = platinumBoxRewardUnits[i];
                    idx++;
                }
            }

            (uint256 platinumBoxPackId, uint256 platinumBoxPackTotalSupply) = lootbox.createPack(
                platinumBoxContents,
                platinumBoxNumOfRewardUnits,
                "https://pack.uri/platinumBox",
                uint128(block.timestamp),
                uint128(1),
                deployOwner
            );

            console.log("platinumBox pack ID:", platinumBoxPackId);
            console.log("platinumBox pack total supply:", platinumBoxPackTotalSupply);
        }

    }

    function createPackStore(address bic, BicPack lootbox, address packStoreOperator) internal {
        // Use edition treasury as sale recipient
        address saleRecipient = vm.envAddress("EDITION_TREASURY_TESTNET");
        PackSaleStore packStore = new PackSaleStore(deployOwner, packStoreOperator, saleRecipient);
        lootbox.setApprovalForAll(address(packStore), true);
        ITokenBundle.Token[] memory packageAssets = new ITokenBundle.Token[](2);
        packageAssets[0] = ITokenBundle.Token({
            assetContract: address(lootbox),
            tokenType: ITokenBundle.TokenType.ERC1155,
            tokenId: 1,
            totalAmount: 2
        });
        packageAssets[1] = ITokenBundle.Token({
            assetContract: address(lootbox),
            tokenType: ITokenBundle.TokenType.ERC1155,
            tokenId: 2,
            totalAmount: 1
        });
        packStore.registerPackage(
            30, 
            packageAssets, 
            100 ether, 
            address(bic)
        );
        console.log("packStore deployed at:", address(packStore));
    }

}