// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {TokenStore} from "../extension/TokenStore.sol";

contract Pack is ERC1155, Ownable, ReentrancyGuard, TokenStore {
    struct PackInfo {
        uint256[] perUnitAmounts;
        uint128 openStartTimestamp;
        uint128 amountDistributedPerOpen;
    }

    // Token name
    string public name;

    // Token symbol
    string public symbol;

    /// @dev The token Id of the next set of packs to be minted.
    uint256 public nextTokenIdToMint;

    /*///////////////////////////////////////////////////////////////
                             Mappings
    //////////////////////////////////////////////////////////////*/

    /// @dev Mapping from token ID => total circulating supply of token with that ID.
    mapping(uint256 => uint256) public totalSupply;

    /// @dev Mapping from pack ID => The state of that set of packs.
    mapping(uint256 => PackInfo) private packInfo;

    /// @dev Checks if pack-creator allowed to add more tokens to a packId; set to false after first transfer
    mapping(uint256 => bool) public canUpdatePack;
    /// @notice Emitted when a set of packs is created.
    event PackCreated(uint256 indexed packId, address recipient, uint256 totalPacksCreated);

    /// @notice Emitted when more packs are minted for a packId.
    event PackUpdated(uint256 indexed packId, address recipient, uint256 totalPacksCreated);

    /// @notice Emitted when a pack is opened.
    event PackOpened(
        uint256 indexed packId,
        address indexed opener,
        uint256 numOfPacksOpened,
        Token[] rewardUnitsDistributed
    );

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        address _owner
    ) ERC1155(_uri) Ownable(_owner) {
        name = _name;
        symbol = _symbol;
    }

    function createPack(
        Token[] calldata _contents,
        uint256[] calldata _numOfRewardUnits,
        string memory _packUri,
        uint128 _openStartTimestamp,
        uint128 _amountDistributedPerOpen,
        address _recipient
    ) external payable onlyOwner returns (uint256 packId, uint256 packTotalSupply) {
        require(_contents.length > 0 && _contents.length == _numOfRewardUnits.length, "!Len");

        packId = nextTokenIdToMint;
        nextTokenIdToMint += 1;

        packTotalSupply = escrowPackContents(
            _contents,
            _numOfRewardUnits,
            _packUri,
            packId,
            _amountDistributedPerOpen,
            false
        );

        packInfo[packId].openStartTimestamp = _openStartTimestamp;
        packInfo[packId].amountDistributedPerOpen = _amountDistributedPerOpen;

        canUpdatePack[packId] = true;

        _mint(_recipient, packId, packTotalSupply, "");

        emit PackCreated(packId, _recipient, packTotalSupply);
    }

    /// @dev Add contents to an existing packId.
    function addPackContents(
        uint256 _packId,
        Token[] calldata _contents,
        uint256[] calldata _numOfRewardUnits,
        address _recipient
    )
    external
    payable
    onlyOwner
    returns (uint256 packTotalSupply, uint256 newSupplyAdded)
    {
        require(canUpdatePack[_packId], "!Allowed");
        require(_contents.length > 0 && _contents.length == _numOfRewardUnits.length, "!Len");
        require(balanceOf(_recipient, _packId) != 0, "!Bal");


        uint256 amountPerOpen = packInfo[_packId].amountDistributedPerOpen;

        newSupplyAdded = escrowPackContents(_contents, _numOfRewardUnits, "", _packId, amountPerOpen, true);
        packTotalSupply = totalSupply[_packId] + newSupplyAdded;

        _mint(_recipient, _packId, newSupplyAdded, "");

        emit PackUpdated(_packId, _recipient, newSupplyAdded);
    }

    /// @notice Lets a pack owner open packs and receive the packs' reward units.
    function openPack(uint256 _packId, uint256 _amountToOpen) external nonReentrant returns (Token[] memory) {
        address opener = _msgSender();

        require(opener == tx.origin, "!EOA");
        require(balanceOf(opener, _packId) >= _amountToOpen, "!Bal");

        PackInfo memory pack = packInfo[_packId];
        require(pack.openStartTimestamp <= block.timestamp, "cant open");

        Token[] memory rewardUnits = getRewardUnits(_packId, _amountToOpen, pack.amountDistributedPerOpen, pack);

        _burn(opener, _packId, _amountToOpen);

        _transferTokenBatch(address(this), opener, rewardUnits);

        emit PackOpened(_packId, opener, _amountToOpen, rewardUnits);

        return rewardUnits;
    }


    /// @dev Stores assets within the contract.
    function escrowPackContents(
        Token[] calldata _contents,
        uint256[] calldata _numOfRewardUnits,
        string memory _packUri,
        uint256 packId,
        uint256 amountPerOpen,
        bool isUpdate
    ) internal returns (uint256 supplyToMint) {
        uint256 sumOfRewardUnits;

        for (uint256 i = 0; i < _contents.length; i += 1) {
            require(_contents[i].totalAmount != 0, "0 amt");
            require(_contents[i].totalAmount % _numOfRewardUnits[i] == 0, "!R");
            require(_contents[i].tokenType != TokenType.ERC721 || _contents[i].totalAmount == 1, "!R");

            sumOfRewardUnits += _numOfRewardUnits[i];

            packInfo[packId].perUnitAmounts.push(_contents[i].totalAmount / _numOfRewardUnits[i]);
        }

        require(sumOfRewardUnits % amountPerOpen == 0, "!Amt");
        supplyToMint = sumOfRewardUnits / amountPerOpen;

        if (isUpdate) {
            for (uint256 i = 0; i < _contents.length; i += 1) {
                _addTokenInBundle(_contents[i], packId);
            }
            _transferTokenBatch(_msgSender(), address(this), _contents);
        } else {
            _storeTokens(_msgSender(), _contents, _packUri, packId);
        }
    }

    /// @dev Returns the reward units to distribute.
    function getRewardUnits(
        uint256 _packId,
        uint256 _numOfPacksToOpen,
        uint256 _rewardUnitsPerOpen,
        PackInfo memory pack
    ) internal returns (Token[] memory rewardUnits) {
        uint256 numOfRewardUnitsToDistribute = _numOfPacksToOpen * _rewardUnitsPerOpen;
        rewardUnits = new Token[](numOfRewardUnitsToDistribute);
        uint256 totalRewardUnits = totalSupply[_packId] * _rewardUnitsPerOpen;
        uint256 totalRewardKinds = getTokenCountOfBundle(_packId);

        uint256 random = generateRandomValue();

        (Token[] memory _token, ) = getPackContents(_packId);
        bool[] memory _isUpdated = new bool[](totalRewardKinds);
        for (uint256 i; i < numOfRewardUnitsToDistribute; ) {
            uint256 randomVal = uint256(keccak256(abi.encode(random, i)));
            uint256 target = randomVal % totalRewardUnits;
            uint256 step;
            for (uint256 j; j < totalRewardKinds; ) {
                uint256 perUnitAmount = pack.perUnitAmounts[j];
                uint256 totalRewardUnitsOfKind = _token[j].totalAmount / perUnitAmount;
                if (target < step + totalRewardUnitsOfKind) {
                    _token[j].totalAmount -= perUnitAmount;
                    _isUpdated[j] = true;
                    rewardUnits[i].assetContract = _token[j].assetContract;
                    rewardUnits[i].tokenType = _token[j].tokenType;
                    rewardUnits[i].tokenId = _token[j].tokenId;
                    rewardUnits[i].totalAmount = perUnitAmount;
                    totalRewardUnits -= 1;
                    break;
                } else {
                    step += totalRewardUnitsOfKind;
                }
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
        for (uint256 i; i < totalRewardKinds; ) {
            if (_isUpdated[i]) {
                _updateTokenInBundle(_token[i], _packId, i);
            }
            unchecked {
                ++i;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                        Getter functions
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the underlying contents of a pack.
    function getPackContents(
        uint256 _packId
    ) public view returns (Token[] memory contents, uint256[] memory perUnitAmounts) {
        PackInfo memory pack = packInfo[_packId];
        uint256 total = getTokenCountOfBundle(_packId);
        contents = new Token[](total);
        perUnitAmounts = new uint256[](total);

        for (uint256 i; i < total; ) {
            contents[i] = getTokenOfBundle(_packId, i);
            unchecked {
                ++i;
            }
        }
        perUnitAmounts = pack.perUnitAmounts;
    }

    function generateRandomValue() internal view returns (uint256 random) {
        random = uint256(keccak256(abi.encodePacked(_msgSender(), blockhash(block.number - 1), block.difficulty)));
    }

    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
     */
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal virtual override {
        super._update(from, to, ids, values);

        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                totalSupply[ids[i]] += values[i];
            }
        } else {
            for (uint256 i = 0; i < ids.length; ++i) {
                // pack can no longer be updated after first transfer to non-zero address
                if (canUpdatePack[ids[i]] && values[i] != 0) {
                    canUpdatePack[ids[i]] = false;
                }
            }
        }

        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                totalSupply[ids[i]] -= values[i];
            }
        }
    }


    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155Holder,ERC1155) returns (bool) {
        return
            super.supportsInterface(interfaceId) ||
            type(IERC721Receiver).interfaceId == interfaceId ||
            type(IERC1155Receiver).interfaceId == interfaceId;
    }
}