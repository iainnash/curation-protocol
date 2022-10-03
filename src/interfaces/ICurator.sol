// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface ICurator {
    /// @notice Shared listing struct for both access and storage.
    struct Listing {
        /// @notice Address that is curated
        address curatedAddress;
        /// @notice Token ID that is selected (see `hasTokenId` to see if this applies)
        uint96 selectedTokenId;
        /// @notice Address that curated this entry
        address curator;
        /// @notice Curation type (see public getters on contract for list of types)
        uint16 curationTargetType;
        /// @notice Optional sort order, can be negative. Utilized optionally like css z-index for sorting.
        int32 sortOrder;
        /// @notice If the token ID applies to the curation (can be whole contract or a specific tokenID)
        bool hasTokenId;
        /// @notice ChainID for curated contract
        uint16 chainId;
    }

    /// @notice Emitted when a listing is added
    event ListingAdded(address indexed curator, Listing listing);

    /// @notice Emitted when a listing is removed
    event ListingRemoved(address indexed curator, Listing listing);

    /// @notice The token pass has been updated for the curation
    /// @dev Any users that have already curated something still can delete their curation.
    event TokenPassUpdated(address indexed owner, address tokenPass);

    /// @notice A new renderer is set
    event SetRenderer(address);

    /// @notice Curation Pause has been udpated.
    event CurationPauseUpdated(address indexed owner, bool isPaused);

    /// @notice Curation limit has beeen updated
    event UpdatedCurationLimit(uint256 newLimit);

    /// @notice Sort order has been updated
    event UpdatedSortOrder(uint256[] ids, int32[] sorts, address updatedBy);

    /// @notice This contract is scheduled to be frozen
    event ScheduledFreeze(uint256 timestamp);

    /// @notice Pass is required to manage curation but not held by attempted updater.
    error PASS_REQUIRED();

    /// @notice Only the curator of a listing (or owner) can manage that curation
    error ONLY_CURATOR();

    /// @notice Wrong curator for the listing when attempting to access the listing.
    error WRONG_CURATOR_FOR_LISTING(address setCurator, address expectedCurator);

    /// @notice Action is unable to complete because the curation is paused.
    error CURATION_PAUSED();

    /// @notice The pause state needs to be toggled and cannot be set to it's current value.
    error CANNOT_SET_SAME_PAUSED_STATE();

    /// @notice Error attempting to update the curation after it has been frozen
    error CURATION_FROZEN();

    /// @notice The curation has gone above the curation limit
    error TOO_MANY_ENTRIES();

    /// @notice Access not allowed by given user
    error ACCESS_NOT_ALLOWED();

    /// @notice attempt to get owner of an unowned / burned token
    error TOKEN_HAS_NO_OWNER();

    /// @notice Array input lengths don't match for sort orders
    error INVALID_INPUT_LENGTH();

    /// @notice Curation limit can only be increased, not decreased.
    error CANNOT_UPDATE_CURATION_LIMIT_DOWN();

    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _tokenPass,
        bool _pause,
        uint256 _curationLimit,
        address _renderer,
        bytes memory _rendererInitializer,
        Listing[] memory _initialListings
    ) external;
}
