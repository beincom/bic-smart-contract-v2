import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ITokenBundle} from "src/extension/interface/ITokenBundle.sol";
import {BicPack} from "src/pack/BicPack.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// Mock ERC20 Token
contract MockERC20 is ERC20 {
    constructor() ERC20("Lucky One BIC", "oBIC") {
        _mint(msg.sender, 3000 ether); // Initial mint for testing
    }
    function mint(address to, uint256 amount) external {
        require(to != address(0), "Invalid address");
        _mint(to, amount);
    }
}

//// Mock ERC721 Token
//contract MockERC721 is ERC721 {
//
//    constructor() ERC721("Just a Test NFT", "JaTNFT") {
//        _mint(msg.sender, 0); // Initial mint for testing
//    }
//
//    function mint(address to, uint256 tokenId) external {
//        require(to != address(0), "Invalid address");
//        _mint(to, tokenId);
//    }
//}

// Mock ERC1155 Token
contract MockERC1155 is ERC1155 {
    string public constant name = "Original Baby Tre";
    string public constant symbol = "OGBT";

    constructor() ERC1155("https://mock.uri/") {
        _mint(msg.sender, 0, 1990, ""); // Initial mint for testing
        _mint(msg.sender, 1, 888, ""); // Initial mint for testing
        _mint(msg.sender, 2, 333, ""); // Initial mint for testing
        _mint(msg.sender, 3, 111, ""); // Initial mint for testing
        _mint(msg.sender, 4, 11, ""); // Initial mint for testing
    }

    function mint(address to, uint256 tokenId, uint256 amount) external {
        require(to != address(0), "Invalid address");
        _mint(to, tokenId, amount, "");
    }
}

contract PackDemo is Script {

    // Deploy mock tokens
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
        address deployOwner = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        MockERC20 mockERC20 = new MockERC20();
//        MockERC721 mockERC721 = new MockERC721();
        MockERC1155 mockERC1155 = new MockERC1155();

        BicPack pack = new BicPack("Demo Loot box", "DEMO-LB", "https://pack.uri/", deployOwner);

        mockERC20.approve(
            address(pack),
            type(uint256).max
        );
//        mockERC721.setApprovalForAll(
//            address(pack),
//            true
//        );
        mockERC1155.setApprovalForAll(
            address(pack),
            true
        );


        ITokenBundle.Token[] memory treLuckyContents = new ITokenBundle.Token[](5);
        uint256[] memory treLuckyNumOfRewardUnits = new uint256[](5);
        treLuckyContents[0] = ITokenBundle.Token(address(mockERC20), ITokenBundle.TokenType.ERC20, 0, 3000 ether);
        treLuckyNumOfRewardUnits[0] = 3000;
        treLuckyContents[1] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 0, 298);
        treLuckyNumOfRewardUnits[1] = 298;
        treLuckyContents[2] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 1, 27);
        treLuckyNumOfRewardUnits[2] = 27;
        treLuckyContents[3] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 2, 7);
        treLuckyNumOfRewardUnits[3] = 7;
        treLuckyContents[4] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 3, 1);
        treLuckyNumOfRewardUnits[4] = 1;

        (uint256 treLuckyPackId, uint256 treLuckyPackTotalSupply) = pack.createPack(
            treLuckyContents,
            treLuckyNumOfRewardUnits,
            "https://pack.uri/1",
            uint128(block.timestamp),
            uint128(1),
            deployOwner
        );
        console.log("Tre lucky pack ID:", treLuckyPackId);
        console.log("Tre lucky pack total supply:", treLuckyPackTotalSupply);

        ITokenBundle.Token[] memory treSproutContents = new ITokenBundle.Token[](5);
        uint256[] memory treSproutNumOfRewardUnits = new uint256[](5);
        treSproutContents[0] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 0, 697);
        treSproutNumOfRewardUnits[0] = 697;
        treSproutContents[1] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 1, 293);
        treSproutNumOfRewardUnits[1] = 293;
        treSproutContents[2] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 2, 7);
        treSproutNumOfRewardUnits[2] = 7;
        treSproutContents[3] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 3, 2);
        treSproutNumOfRewardUnits[3] = 2;
        treSproutContents[4] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 4, 1);
        treSproutNumOfRewardUnits[4] = 1;

        (uint256 treSproutPackId, uint256 treSproutPackTotalSupply) = pack.createPack(
            treSproutContents,
            treSproutNumOfRewardUnits,
            "https://pack.uri/2",
            uint128(block.timestamp),
            uint128(1),
            deployOwner
        );
        console.log("Tre sprout pack ID:", treSproutPackId);
        console.log("Tre sprout pack total supply:", treSproutPackTotalSupply);

        ITokenBundle.Token[] memory treSpiritContents = new ITokenBundle.Token[](5);
        uint256[] memory treSpiritNumOfRewardUnits = new uint256[](5);
        treSpiritContents[0] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 0, 597);
        treSpiritNumOfRewardUnits[0] = 597;
        treSpiritContents[1] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 1, 284);
        treSpiritNumOfRewardUnits[1] = 284;
        treSpiritContents[2] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 2, 83);
        treSpiritNumOfRewardUnits[2] = 83;
        treSpiritContents[3] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 3, 33);
        treSpiritNumOfRewardUnits[3] = 33;
        treSpiritContents[4] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 4, 3);
        treSpiritNumOfRewardUnits[4] = 3;

        (uint256 treSpiritPackId, uint256 treSpiritPackTotalSupply) = pack.createPack(
            treSpiritContents,
            treSpiritNumOfRewardUnits,
            "https://pack.uri/3",
            uint128(block.timestamp),
            uint128(1),
            deployOwner
        );
        console.log("Tre spirit pack ID:", treSpiritPackId);
        console.log("Tre spirit pack total supply:", treSpiritPackTotalSupply);

        ITokenBundle.Token[] memory treGuardianContents = new ITokenBundle.Token[](5);
        uint256[] memory treGuardianNumOfRewardUnits = new uint256[](5);
        treGuardianContents[0] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 0, 398);
        treGuardianNumOfRewardUnits[0] = 398;
        treGuardianContents[1] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 1, 284);
        treGuardianNumOfRewardUnits[1] = 284;
        treGuardianContents[2] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 2, 236);
        treGuardianNumOfRewardUnits[2] = 236;
        treGuardianContents[3] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 3, 75);
        treGuardianNumOfRewardUnits[3] = 75;
        treGuardianContents[4] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 4, 7);
        treGuardianNumOfRewardUnits[4] = 7;
        (uint256 treGuardianPackId, uint256 treGuardianPackTotalSupply) = pack.createPack(
            treGuardianContents,
            treGuardianNumOfRewardUnits,
            "https://pack.uri/4",
            uint128(block.timestamp),
            uint128(1),
            deployOwner
        );
        console.log("Tre guardian pack ID:", treGuardianPackId);
        console.log("Tre guardian pack total supply:", treGuardianPackTotalSupply);

        vm.stopBroadcast();
    }
}