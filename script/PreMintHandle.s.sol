// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HandlesController} from "../src/namespaces/HandlesController.sol";
import {Handles} from "../src/namespaces/Handles.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IMulticall3 {
  struct Call {
    address target;
    bytes callData;
  }

  struct Call3 {
    address target;
    bool allowFailure;
    bytes callData;
  }

  struct Call3Value {
    address target;
    bool allowFailure;
    uint256 value;
    bytes callData;
  }

  struct Result {
    bool success;
    bytes returnData;
  }

  function aggregate(Call[] calldata calls)
    external
    payable
    returns (uint256 blockNumber, bytes[] memory returnData);

  function aggregate3(Call3[] calldata calls) external payable returns (Result[] memory returnData);

  function aggregate3Value(Call3Value[] calldata calls)
    external
    payable
    returns (Result[] memory returnData);
}
contract PremintNFTScript is Script {
    using ECDSA for bytes32;

    // Contract addresses and key configs
    address public handlesController;
    address public uoNFTHandle;
    address public poNFTHandle;
    address public pbNFTHandle;
    address public coNFTHandle;
    address public receiver;
    address public multicall;
    uint256 public operatorPrivateKey;

    // Struct to hold handle request data
    struct HandleRequestData {
        string name;
        address handleContract;
    }

    function setUp() public {
        // Update addresses
        handlesController = vm.envAddress("CONTROLLER_ADDRESS");
        uoNFTHandle = vm.envAddress("NFT_OWNERSHIP_USERNAME_COLLECTION_ADDRESS");
        poNFTHandle = vm.envAddress("NFT_OWNERSHIP_PERSONAL_NAME_COLLECTION_ADDRESS");
        pbNFTHandle = vm.envAddress("NFT_EARNING_PERSONAL_NAME_COLLECTION_ADDRESS");
        coNFTHandle = vm.envAddress("NFT_OWNERSHIP_COMMUNITY_NAME_COLLECTION_ADDRESS");
        receiver = vm.envAddress("PREMINT_RECEIVER_ADDRESS");
        multicall = 0xcA11bde05977b3631167028862bE2a173976CA11;
        operatorPrivateKey = vm.envUint("NFT_OPERATOR_PRIVATE_KEY");
    }

    function run() public {

        HandleRequestData[] memory allHandles = getAllHandleRequests();
        // HandleRequestData[] memory allHandles = getAllHandleRequestsForTest();
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](allHandles.length);
        
        console.log("Length handle is:", allHandles.length);

        
        // Empty arrays for beneficiaries and collects
        address[] memory beneficiaries = new address[](0);
        uint256[] memory collects = new uint256[](0);
        
        // Calculate validity period (same for all requests)
        uint256 validAfter = block.timestamp - 1;
        uint256 validUntil = block.timestamp + 1 hours;

        // Prepare all calls
        for (uint i = 0; i < allHandles.length; i++) {
            HandlesController.HandleRequest memory request = HandlesController.HandleRequest({
                receiver: receiver,
                handle: allHandles[i].handleContract,
                name: allHandles[i].name,
                price: 0,
                beneficiaries: beneficiaries,
                collects: collects,
                commitDuration: 0,
                buyoutBidAmount: 0,
                timeBufferInSeconds: 0,
                bidBufferBps: 0,
                isAuction: false
            });

            // Get message hash and signature
            bytes32 messageHash = HandlesController(handlesController).getRequestHandleOp(
                request,
                validUntil,
                validAfter
            );
            bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(operatorPrivateKey, ethSignedMessageHash);
            bytes memory signature = abi.encodePacked(r, s, v);

            // Prepare multicall data
            calls[i] = IMulticall3.Call3({
                target: handlesController,
                allowFailure: false,
                callData: abi.encodeWithSelector(
                    HandlesController.requestHandle.selector,
                    request,
                    validUntil,
                    validAfter,
                    signature
                )
            });

            console.log("Prepared request for handle:", allHandles[i].name);
            console.log("Handle contract:", allHandles[i].handleContract);
        }

        // Execute all calls in a single transaction
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        IMulticall3(multicall).aggregate3(calls);

        // Verify all handles are owned by receiver
        for (uint256 i = 0; i < allHandles.length; i++) {
            Handles handle = Handles(allHandles[i].handleContract);
            require(
                handle.ownerOf(handle.getTokenId(allHandles[i].name)) == receiver,
                "Handle NFT not owned by receiver"
            );
        }
        vm.stopBroadcast();
    }

    function getAllHandleRequests() internal view returns (HandleRequestData[] memory) {
        // Username Ownership NFTs (uoNFT)
        HandleRequestData[] memory uoHandles = new HandleRequestData[](9);
        uoHandles[0] = HandleRequestData(unicode"contact", uoNFTHandle);
        uoHandles[1] = HandleRequestData(unicode"bicsupport", uoNFTHandle);
        uoHandles[2] = HandleRequestData(unicode"beincom.global.admin", uoNFTHandle);
        uoHandles[3] = HandleRequestData(unicode"crisbicsupport", uoNFTHandle);
        uoHandles[4] = HandleRequestData(unicode"lilybicsupport", uoNFTHandle);
        uoHandles[5] = HandleRequestData(unicode"canarybicsupport", uoNFTHandle);
        uoHandles[6] = HandleRequestData(unicode"dylanbicsupport", uoNFTHandle);
        uoHandles[7] = HandleRequestData(unicode"beincom", uoNFTHandle);
        uoHandles[8] = HandleRequestData(unicode"beincomadmin", uoNFTHandle);

        // Personal Name Ownership NFTs (poNFT)
        HandleRequestData[] memory poHandles = new HandleRequestData[](9);
        poHandles[0] = HandleRequestData(unicode"Beincom Official", poNFTHandle);
        poHandles[1] = HandleRequestData(unicode"Beincom Vietnam Admin", poNFTHandle);
        poHandles[2] = HandleRequestData(unicode"Beincom Global Admin", poNFTHandle);
        poHandles[3] = HandleRequestData(unicode"Lily Beincom Support", poNFTHandle);
        poHandles[4] = HandleRequestData(unicode"Canary Beincom Support", poNFTHandle);
        poHandles[5] = HandleRequestData(unicode"Cris Beincom Support", poNFTHandle);
        poHandles[6] = HandleRequestData(unicode"Dylan Beincom Support", poNFTHandle);
        poHandles[7] = HandleRequestData(unicode"Beincom", poNFTHandle);
        poHandles[8] = HandleRequestData(unicode"Beincom Admin", poNFTHandle);

        // Community Name Ownership NFTs (coNFT)
        HandleRequestData[] memory coHandles = new HandleRequestData[](4);
        coHandles[0] = HandleRequestData(unicode"Beincom Việt Nam", coNFTHandle);
        coHandles[1] = HandleRequestData(unicode"Beincom Global", coNFTHandle);
        coHandles[2] = HandleRequestData(unicode"Beincom's EchoSphere", coNFTHandle);
        coHandles[3] = HandleRequestData(unicode"Beincom", coNFTHandle);

        // Combine all handles
        HandleRequestData[] memory allHandles = new HandleRequestData[](
            uoHandles.length + poHandles.length + coHandles.length
        );
        
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < uoHandles.length; i++) {
            allHandles[currentIndex++] = uoHandles[i];
        }
        for (uint256 i = 0; i < poHandles.length; i++) {
            allHandles[currentIndex++] = poHandles[i];
        }
        for (uint256 i = 0; i < coHandles.length; i++) {
            allHandles[currentIndex++] = coHandles[i];
        }

        return allHandles;
    }

    function getAllHandleRequestsForTest() internal view returns (HandleRequestData[] memory) {
        // Username Ownership NFTs (uoNFT)
        HandleRequestData[] memory uoHandles = new HandleRequestData[](1);
        uoHandles[0] = HandleRequestData(unicode"beincomnfttest0000000000000000002", uoNFTHandle);

        // Personal Name Ownership NFTs (poNFT)
        HandleRequestData[] memory poHandles = new HandleRequestData[](1);
        poHandles[0] = HandleRequestData(unicode"Beincom poNFT Test 0000000000000000002", poNFTHandle);

        // Community Name Ownership NFTs (coNFT)
        HandleRequestData[] memory coHandles = new HandleRequestData[](1);
        coHandles[0] = HandleRequestData(unicode"Beincom coNFT Test 0000000000000000002", coNFTHandle);

        // Combine all handles
        HandleRequestData[] memory allHandles = new HandleRequestData[](
            uoHandles.length + poHandles.length + coHandles.length
        );
        
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < uoHandles.length; i++) {
            allHandles[currentIndex++] = uoHandles[i];
        }
        for (uint256 i = 0; i < poHandles.length; i++) {
            allHandles[currentIndex++] = poHandles[i];
        }
        for (uint256 i = 0; i < coHandles.length; i++) {
            allHandles[currentIndex++] = coHandles[i];
        }

        return allHandles;
    }
}


contract PremintVietnamNFTScript is Script {
    using ECDSA for bytes32;

    // Contract addresses and key configs
    address public handlesController;
    address public uoNFTHandle;
    address public poNFTHandle;
    address public pbNFTHandle;
    address public coNFTHandle;
    address public receiver;
    address public multicall;
    uint256 public operatorPrivateKey;

    // Struct to hold handle request data
    struct HandleRequestData {
        string name;
        address handleContract;
    }

    function setUp() public {
        // Update addresses
        handlesController = vm.envAddress("CONTROLLER_ADDRESS");
        uoNFTHandle = vm.envAddress("NFT_OWNERSHIP_USERNAME_COLLECTION_ADDRESS");
        poNFTHandle = vm.envAddress("NFT_OWNERSHIP_PERSONAL_NAME_COLLECTION_ADDRESS");
        pbNFTHandle = vm.envAddress("NFT_EARNING_PERSONAL_NAME_COLLECTION_ADDRESS");
        coNFTHandle = vm.envAddress("NFT_OWNERSHIP_COMMUNITY_NAME_COLLECTION_ADDRESS");
        receiver = vm.envAddress("PREMINT_RECEIVER_ADDRESS");
        multicall = 0xcA11bde05977b3631167028862bE2a173976CA11;
        operatorPrivateKey = vm.envUint("NFT_OPERATOR_PRIVATE_KEY");
    }

    function run() public {        
        // Empty arrays for beneficiaries and collects
        address[] memory beneficiaries = new address[](0);
        uint256[] memory collects = new uint256[](0);
        
        // Calculate validity period (same for all requests)
        uint256 validAfter = block.timestamp - 1;
        uint256 validUntil = block.timestamp + 1 hours;
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // Vietnam people
        HandleRequestData[] memory vietnamPoHandles = getVietnamPeopleName(poNFTHandle);
        IMulticall3.Call3[] memory poHandlesCalls = new IMulticall3.Call3[](vietnamPoHandles.length);
        for (uint i = 0; i < vietnamPoHandles.length; i++) {
            HandlesController.HandleRequest memory request = HandlesController.HandleRequest({
                receiver: receiver,
                handle: vietnamPoHandles[i].handleContract,
                name: vietnamPoHandles[i].name,
                price: 0,
                beneficiaries: beneficiaries,
                collects: collects,
                commitDuration: 0,
                buyoutBidAmount: 0,
                timeBufferInSeconds: 0,
                bidBufferBps: 0,
                isAuction: false
            });

            // Get message hash and signature
            bytes32 messageHash = HandlesController(handlesController).getRequestHandleOp(
                request,
                validUntil,
                validAfter
            );
            bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(operatorPrivateKey, ethSignedMessageHash);
            bytes memory signature = abi.encodePacked(r, s, v);

            // Prepare multicall data
            poHandlesCalls[i] = IMulticall3.Call3({
                target: handlesController,
                allowFailure: false,
                callData: abi.encodeWithSelector(
                    HandlesController.requestHandle.selector,
                    request,
                    validUntil,
                    validAfter,
                    signature
                )
            });

            console.log("Prepared request for handle:", vietnamPoHandles[i].name);
            console.log("Handle contract:", vietnamPoHandles[i].handleContract);
        }
        IMulticall3(multicall).aggregate3(poHandlesCalls);
        // Verify all handles are owned by receiver
        for (uint256 i = 0; i < vietnamPoHandles.length; i++) {
            Handles handle = Handles(vietnamPoHandles[i].handleContract);
            require(
                handle.ownerOf(handle.getTokenId(vietnamPoHandles[i].name)) == receiver,
                "Handle NFT not owned by receiver"
            );
        }

        HandleRequestData[] memory vietnamPbHandles = getVietnamPeopleName(pbNFTHandle);
        IMulticall3.Call3[] memory pbHandlesCalls = new IMulticall3.Call3[](vietnamPbHandles.length);
        for (uint i = 0; i < vietnamPbHandles.length; i++) {
            HandlesController.HandleRequest memory request = HandlesController.HandleRequest({
                receiver: receiver,
                handle: vietnamPbHandles[i].handleContract,
                name: vietnamPbHandles[i].name,
                price: 0,
                beneficiaries: beneficiaries,
                collects: collects,
                commitDuration: 0,
                buyoutBidAmount: 0,
                timeBufferInSeconds: 0,
                bidBufferBps: 0,
                isAuction: false
            });

            // Get message hash and signature
            bytes32 messageHash = HandlesController(handlesController).getRequestHandleOp(
                request,
                validUntil,
                validAfter
            );
            bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(operatorPrivateKey, ethSignedMessageHash);
            bytes memory signature = abi.encodePacked(r, s, v);

            // Prepare multicall data
            pbHandlesCalls[i] = IMulticall3.Call3({
                target: handlesController,
                allowFailure: false,
                callData: abi.encodeWithSelector(
                    HandlesController.requestHandle.selector,
                    request,
                    validUntil,
                    validAfter,
                    signature
                )
            });

            console.log("Prepared request for handle:", vietnamPbHandles[i].name);
            console.log("Handle contract:", vietnamPbHandles[i].handleContract);
        }

        IMulticall3(multicall).aggregate3(pbHandlesCalls);
        for (uint256 i = 0; i < vietnamPbHandles.length; i++) {
            Handles handle = Handles(vietnamPbHandles[i].handleContract);
            require(
                handle.ownerOf(handle.getTokenId(vietnamPbHandles[i].name)) == receiver,
                "Handle NFT not owned by receiver"
            );
        }

        HandleRequestData[] memory vietnamCoHandles = getVietnamPeopleName(coNFTHandle);
        IMulticall3.Call3[] memory coHandlesCalls = new IMulticall3.Call3[](vietnamCoHandles.length);
        for (uint i = 0; i < vietnamCoHandles.length; i++) {
            HandlesController.HandleRequest memory request = HandlesController.HandleRequest({
                receiver: receiver,
                handle: vietnamCoHandles[i].handleContract,
                name: vietnamCoHandles[i].name,
                price: 0,
                beneficiaries: beneficiaries,
                collects: collects,
                commitDuration: 0,
                buyoutBidAmount: 0,
                timeBufferInSeconds: 0,
                bidBufferBps: 0,
                isAuction: false
            });

            // Get message hash and signature
            bytes32 messageHash = HandlesController(handlesController).getRequestHandleOp(
                request,
                validUntil,
                validAfter
            );
            bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(operatorPrivateKey, ethSignedMessageHash);
            bytes memory signature = abi.encodePacked(r, s, v);

            // Prepare multicall data
            coHandlesCalls[i] = IMulticall3.Call3({
                target: handlesController,
                allowFailure: false,
                callData: abi.encodeWithSelector(
                    HandlesController.requestHandle.selector,
                    request,
                    validUntil,
                    validAfter,
                    signature
                )
            });

            console.log("Prepared request for handle:", vietnamCoHandles[i].name);
            console.log("Handle contract:", vietnamCoHandles[i].handleContract);
        }
        IMulticall3(multicall).aggregate3(coHandlesCalls);
        // Verify all handles are owned by receiver
        for (uint256 i = 0; i < vietnamCoHandles.length; i++) {
            Handles handle = Handles(vietnamCoHandles[i].handleContract);
            require(
                handle.ownerOf(handle.getTokenId(vietnamCoHandles[i].name)) == receiver,
                "Handle NFT not owned by receiver"
            );
        }
        

        vm.stopBroadcast();
    }

    function getVietnamPeopleName(address nftHandle) public pure returns(HandleRequestData[] memory) {
        // Vietnam’s Greate People - Profile Name Ownership/Profile Name Base
        HandleRequestData[] memory pbHandles = new HandleRequestData[](63);
        pbHandles[0] = HandleRequestData(unicode"Bùi Thanh Sơn", nftHandle);
        pbHandles[1] = HandleRequestData(unicode"Bùi Thị Minh Hoài", nftHandle);
        pbHandles[2] = HandleRequestData(unicode"Đào Hồng Lan", nftHandle);
        pbHandles[3] = HandleRequestData(unicode"Đào Ngọc Dung", nftHandle);
        pbHandles[4] = HandleRequestData(unicode"Đoàn Hồng Phong", nftHandle);
        pbHandles[5] = HandleRequestData(unicode"Đỗ Đức Duy", nftHandle);
        pbHandles[6] = HandleRequestData(unicode"Đỗ Văn Chiến", nftHandle);
        pbHandles[7] = HandleRequestData(unicode"Hồ Chí Minh", nftHandle);
        pbHandles[8] = HandleRequestData(unicode"Hồ Đức Phớc", nftHandle);
        pbHandles[9] = HandleRequestData(unicode"Hoàng Văn Thái", nftHandle);
        pbHandles[10] = HandleRequestData(unicode"Lê Duẩn", nftHandle);
        pbHandles[11] = HandleRequestData(unicode"Lê Khả Phiêu", nftHandle);
        pbHandles[12] = HandleRequestData(unicode"Lê Minh Hưng", nftHandle);
        pbHandles[13] = HandleRequestData(unicode"Lê Quang Đạo", nftHandle);
        pbHandles[14] = HandleRequestData(unicode"Lê Thành Long", nftHandle);
        pbHandles[15] = HandleRequestData(unicode"Lê Trọng Tấn", nftHandle);
        pbHandles[16] = HandleRequestData(unicode"Lê Đức Anh", nftHandle);
        pbHandles[17] = HandleRequestData(unicode"Lương Cường", nftHandle);
        pbHandles[18] = HandleRequestData(unicode"Lương Tam Quang", nftHandle);
        pbHandles[19] = HandleRequestData(unicode"Mai Văn Chính", nftHandle);
        pbHandles[20] = HandleRequestData(unicode"Nguyễn Chí Dũng", nftHandle);
        pbHandles[21] = HandleRequestData(unicode"Nguyễn Chí Thanh", nftHandle);
        pbHandles[22] = HandleRequestData(unicode"Nguyễn Duy Ngọc", nftHandle);
        pbHandles[23] = HandleRequestData(unicode"Nguyễn Hải Ninh", nftHandle);
        pbHandles[24] = HandleRequestData(unicode"Nguyễn Hòa Bình", nftHandle);
        pbHandles[25] = HandleRequestData(unicode"Nguyễn Hồng Diên", nftHandle);
        pbHandles[26] = HandleRequestData(unicode"Nguyễn Kim Sơn", nftHandle);
        pbHandles[27] = HandleRequestData(unicode"Nguyễn Mạnh Hùng", nftHandle);
        pbHandles[28] = HandleRequestData(unicode"Nguyễn Minh Triết", nftHandle);
        pbHandles[29] = HandleRequestData(unicode"Nguyễn Phú Trọng", nftHandle);
        pbHandles[30] = HandleRequestData(unicode"Nguyễn Sinh Hùng", nftHandle);
        pbHandles[31] = HandleRequestData(unicode"Nguyễn Thị Hồng", nftHandle);
        pbHandles[32] = HandleRequestData(unicode"Nguyễn Thị Kim Ngân", nftHandle);
        pbHandles[33] = HandleRequestData(unicode"Nguyễn Trọng Nghĩa", nftHandle);
        pbHandles[34] = HandleRequestData(unicode"Nguyễn Tấn Dũng", nftHandle);
        pbHandles[35] = HandleRequestData(unicode"Nguyễn Văn An", nftHandle);
        pbHandles[36] = HandleRequestData(unicode"Nguyễn Văn Hùng", nftHandle);
        pbHandles[37] = HandleRequestData(unicode"Nguyễn Văn Nên", nftHandle);
        pbHandles[38] = HandleRequestData(unicode"Nguyễn Văn Thắng", nftHandle);
        pbHandles[39] = HandleRequestData(unicode"Nguyễn Văn Linh", nftHandle);
        pbHandles[40] = HandleRequestData(unicode"Nguyễn Xuân Phúc", nftHandle);
        pbHandles[41] = HandleRequestData(unicode"Nguyễn Xuân Thắng", nftHandle);
        pbHandles[42] = HandleRequestData(unicode"Phạm Minh Chính", nftHandle);
        pbHandles[43] = HandleRequestData(unicode"Phạm Thị Thanh Trà", nftHandle);
        pbHandles[44] = HandleRequestData(unicode"Phạm Văn Đồng", nftHandle);
        pbHandles[45] = HandleRequestData(unicode"Phan Đình Trạc", nftHandle);
        pbHandles[46] = HandleRequestData(unicode"Phan Văn Giang", nftHandle);
        pbHandles[47] = HandleRequestData(unicode"Phan Văn Khải", nftHandle);
        pbHandles[48] = HandleRequestData(unicode"Tôn Đức Thắng", nftHandle);
        pbHandles[49] = HandleRequestData(unicode"Tô Lâm", nftHandle);
        pbHandles[50] = HandleRequestData(unicode"Trần Cẩm Tú", nftHandle);
        pbHandles[51] = HandleRequestData(unicode"Trần Đại Quang", nftHandle);
        pbHandles[52] = HandleRequestData(unicode"Trần Đức Lương", nftHandle);
        pbHandles[53] = HandleRequestData(unicode"Trần Hồng Hà", nftHandle);
        pbHandles[54] = HandleRequestData(unicode"Trần Hồng Minh", nftHandle);
        pbHandles[55] = HandleRequestData(unicode"Trần Thanh Mẫn", nftHandle);
        pbHandles[56] = HandleRequestData(unicode"Trần Văn Sơn", nftHandle);
        pbHandles[57] = HandleRequestData(unicode"Trương Tấn Sang", nftHandle);
        pbHandles[58] = HandleRequestData(unicode"Trường Chinh", nftHandle);
        pbHandles[59] = HandleRequestData(unicode"Võ Chí Công", nftHandle);
        pbHandles[60] = HandleRequestData(unicode"Võ Nguyên Giáp", nftHandle);
        pbHandles[61] = HandleRequestData(unicode"Võ Văn Kiệt", nftHandle);
        pbHandles[62] = HandleRequestData(unicode"Vương Đình Huệ", nftHandle);
        return pbHandles;
    }
}
