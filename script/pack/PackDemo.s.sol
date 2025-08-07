import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ITokenBundle} from "src/extension/interface/ITokenBundle.sol";
import {BicPack} from "src/pack/BicPack.sol";
import {Script} from "forge-std/Script.sol";

// Mock ERC20 Token
contract MockERC20 is ERC20 {
    constructor() ERC20("Just a Test Token", "JaTT") {
        _mint(msg.sender, 510 ether); // Initial mint for testing
    }
    function mint(address to, uint256 amount) external {
        require(to != address(0), "Invalid address");
        _mint(to, amount);
    }
}

// Mock ERC721 Token
contract MockERC721 is ERC721 {

    constructor() ERC721("Just a Test NFT", "JaTNFT") {
        _mint(msg.sender, 0); // Initial mint for testing
    }

    function mint(address to, uint256 tokenId) external {
        require(to != address(0), "Invalid address");
        _mint(to, tokenId);
    }
}

// Mock ERC1155 Token
contract MockERC1155 is ERC1155 {
    string public constant name = "Just a Test Edition";
    string public constant symbol = "JaTE";

    constructor() ERC1155("https://mock.uri/") {
        _mint(msg.sender, 0, 80, ""); // Initial mint for testing
        _mint(msg.sender, 1, 30, ""); // Initial mint for testing
        _mint(msg.sender, 2, 2, ""); // Initial mint for testing
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
        MockERC721 mockERC721 = new MockERC721();
        MockERC1155 mockERC1155 = new MockERC1155();

        BicPack pack = new BicPack("Demo pack", "DEMO-PACK", "https://pack.uri/", deployOwner);

        mockERC20.approve(
            address(pack),
            type(uint256).max
        );
        mockERC721.setApprovalForAll(
            address(pack),
            true
        );
        mockERC1155.setApprovalForAll(
            address(pack),
            true
        );


        ITokenBundle.Token[] memory contents = new ITokenBundle.Token[](6);
        uint256[] memory numOfRewardUnits = new uint256[](6);

        contents[0] = ITokenBundle.Token(address(mockERC20), ITokenBundle.TokenType.ERC20, 0, 10 ether);
        numOfRewardUnits[0] = 10;
        contents[1] = ITokenBundle.Token(address(mockERC20), ITokenBundle.TokenType.ERC20, 0, 500 ether);
        numOfRewardUnits[1] = 5;
        contents[2] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 0, 80);
        numOfRewardUnits[2] = 4;
        contents[3] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 1, 30);
        numOfRewardUnits[3] = 3;
        contents[4] = ITokenBundle.Token(address(mockERC1155), ITokenBundle.TokenType.ERC1155, 2, 2);
        numOfRewardUnits[4] = 2;
        contents[5] = ITokenBundle.Token(address(mockERC721), ITokenBundle.TokenType.ERC721, 0, 1);
        numOfRewardUnits[5] = 1;

        (uint256 packId, uint256 packTotalSupply) = pack.createPack(
            contents,
            numOfRewardUnits,
            "https://pack.uri/",
            uint128(block.timestamp),
            uint128(1), // 2 reward units per open
            deployOwner
        );

        vm.stopBroadcast();
    }
}