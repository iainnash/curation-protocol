// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { IERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import { UUPS } from "./lib/proxy/UUPS.sol";
import { Ownable } from "./lib/utils/Ownable.sol";
import { ICuratorFactory } from "./interfaces/ICuratorFactory.sol";
import { ICurator } from "./interfaces/ICurator.sol";
import { CuratorSkeletonNFT } from "./CuratorSkeletonNFT.sol";

abstract contract CuratorStorageV1 is ICurator {
    string internal contractName;

    string internal contractSymbol;

    IERC721Upgradeable public curationPass;

    uint40 public numAdded;

    uint40 public numRemoved;

    bool public isPaused;

    uint256 public frozenAt;

    uint256 public curationLimit;

    address public renderer;

    /// @dev Listing id => Listing address
    mapping(uint256 => Listing) public idToListing;
}

contract Curator is UUPS, Ownable, CuratorStorageV1, CuratorSkeletonNFT {
    uint256 public constant CURATION_TYPE_GENERIC = 0;
    uint256 public constant CURATION_TYPE_NFT_CONTRACT = 1;
    uint256 public constant CURATION_TYPE_CURATION_CONTRACT = 2;
    uint256 public constant CURATION_TYPE_CONTRACT = 3;
    uint256 public constant CURATION_TYPE_NFT_ITEM = 4;
    uint256 public constant CURATION_TYPE_EOA_WALLET = 5;

    ICuratorFactory private immutable curatorFactory;
    IRenderer private immutable defaultRenderer;

    modifier onlyActive() {
        if (isPaused && msg.sender != owner()) {
            revert CURATION_PAUSED();
        }

        if (frozenAt != 0 && frozenAt < block.timestamp) {
            revert CURATION_FROZEN();
        }

        _;
    }

    modifier onlyCuratorOrAdmin(uint256 listingId) {
        if (owner() != msg.sender || idToListing[listingId].curator != msg.sender) {
            revert NOT_ALLOWED();
        }

        _;
    }

    constructor(address _curatorFactory, address _defaultRenderer) payable initializer {
        curatorFactory = ICuratorFactory(_curatorFactory);
        defaultRenderer = IRenderer(_defaultRenderer);
    }

    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _curationPass,
        bool _pause,
        uint256 _curationLimit,
        address renderer
    ) external initializer {
        __Ownable_init(_owner);

        contractName = _name;
        contractSymbol = _symbol;

        curationPass = IERC721Upgradeable(_curationPass);

        if (_pause) {
            _setCurationPaused(_pause);
        }

        if (_curationLimit != 0) {
            _updateCurationLimit(_curationLimit);
        }
    }

    function getListings() external view returns (Listing[] memory activeListings) {
        unchecked {
            activeListings = new Listing[](numAdded - numRemoved);

            uint256 activeIndex;

            for (uint256 i; i < numAdded; ++i) {
                if (idToListing[i].curator == address(0)) {
                    continue;
                }

                activeListings[activeIndex] = idToListing[i];
                ++activeIndex;
            }
        }
    }

    function addListings(Listing[] calldata listings) external onlyActive {
        if (curationPass.balanceOf(msg.sender) == 0) {
            if (msg.sender != owner()) {
                revert PASS_REQUIRED();
            }
        }

        if (curationLimit != 0 && numAdded - numRemoved + listings.length > curationLimit) {
            revert HAS_TOO_MANY_ITEMS();
        }

        for (uint256 i = 0; i < listings.length; ++i) {
            if (listings[i].curator != msg.sender) {
                revert WRONG_CURATOR_FOR_LISTING(listings[i].curator, msg.sender);
            }
            idToListing[numAdded] = listings[i];
            idToListing[numAdded].curator = msg.sender;
            ++numAdded;
        }
    }

    function updateCurationLimit(uint256 newLimit) external onlyOwner {
        _updateCurationLimit(newLimit);
    }

    function _updateCurationLimit(uint256 newLimit) internal {
        if (curationLimit < newLimit && curationLimit != 0) {
            revert CANNOT_UPDATE_CURATION_LIMIT_DOWN();
        }
        curationLimit = newLimit;
        emit UpdatedCurationLimit(newLimit);
    }

    function updateSortOrders(uint256[] calldata tokenIds, int32[] calldata sortOrders) external onlyActive {
        if (tokenIds.length != sortOrders.length) {
            revert INVALID_INPUT_LENGTH();
        }
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _setSortOrder(tokenIds[i], sortOrders[i]);
        }
        emit UpdatedSortOrder(tokenIds, sortOrders, msg.sender);
    }

    function _setSortOrder(uint256 listingId, int32 sortOrder) internal onlyCuratorOrAdmin(listingId) {
        idToListing[listingId].sortOrder = sortOrder;
    }

    function freezeAt(uint256 timestamp) external onlyOwner {
        if (frozenAt != 0 && frozenAt < block.timestamp) {
            revert CURATION_FROZEN();
        }
        frozenAt = timestamp;
        emit ScheduledFreeze(frozenAt);
    }

    function burn(uint256 listingId) public onlyActive {
        _burnTokenWithChecks(listingId);
    }

    function burnBatch(uint256[] calldata listingIds) external {
        unchecked {
            for (uint256 i = 0; i < listingIds.length; ++i) {
                _burnTokenWithChecks(listingIds[i]);
            }
        }
    }

    // nft functions

    function _exists(uint256 id) internal view virtual override returns (bool) {
        return idToListing[id].curator != address(0);
    }

    function balanceOf(address _owner) public view override returns (uint256 balance) {
        for (uint256 i = 0; i < numAdded; ++i) {
            if (idToListing[i].curator == _owner) {
                ++balance;
            }
        }
    }

    function name() external view override returns (string memory) {
        return contractName;
    }

    function symbol() external view override returns (string memory) {
        return contractSymbol;
    }

    function totalSupply() public view override returns (uint256) {
        return numAdded - numRemoved;
    }

    function ownerOf(uint256 id) public view virtual override returns (address) {
        if (!_exists(id)) {
            revert NO_OWNER();
        }
        return idToListing[id].curator;
    }

    function tokenURI(uint256 token) external view override returns (string memory) {
        // TODO
        return "";
        // return renderer.tokenURI(token);
    }

    function contractURI() external view override returns (string memory) {
        // TODO
        return "";
        // return renderer.contractURI(token);
    }

    function _burnTokenWithChecks(uint256 listingId) internal onlyActive onlyCuratorOrAdmin(listingId) {
        Listing memory _listing = idToListing[listingId];
        delete idToListing[listingId];
        unchecked {
            ++numRemoved;
        }

        // burn nft
        _burn(listingId);

        emit ListingRemoved(msg.sender, _listing);
    }

    function updateCurationPass(IERC721Upgradeable _curationPass) public onlyOwner {
        curationPass = _curationPass;

        emit TokenPassUpdated(msg.sender, address(_curationPass));
    }

    function pauseCuration() public onlyOwner {
        _setCurationPaused(true);
    }

    function resumeCuration() public onlyOwner {
        _setCurationPaused(false);
    }

    function _setCurationPaused(bool _setPaused) internal {
        if (_setPaused) {
            emit CurationPaused(msg.sender);
        } else {
            emit CurationResumed(msg.sender);
        }

        isPaused = _setPaused;
    }

    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner {
        if (!curatorFactory.isValidUpgrade(_getImplementation(), _newImpl)) {
            revert INVALID_UPGRADE(_newImpl);
        }
    }
}
