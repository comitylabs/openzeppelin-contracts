pragma solidity ^0.8.0;

import "../../utils/Context.sol";
import "./extensions/IERC721Rent.sol";
import "../../utils/introspection/ERC165.sol";

contract ERC721SwapRentAgreement is Context, IERC721RentAgreement, ERC165 {
    enum RentStatus {
        pending,
        active
    }

    struct Token {
        IERC721Rent source;
        bool approvedForRent;
        uint256 tokenId;
    }

    struct RentAgreement {
        Token token1;
        Token token2;
        uint40 startTime;
        uint40 rentDuration;
        uint40 rentExpirationTime;
        RentStatus rentStatus;
    }

    RentAgreement public rentAgreement;

    constructor(
        IERC721Rent _source1,
        IERC721Rent _source2,
        uint256 _tokenId1,
        uint256 _tokenId2,
        uint40 _rentDuration,
        uint40 _rentExpirationTime
    ) {
        Token memory token1 = Token(_source1, false, _tokenId1);
        Token memory token2 = Token(_source2, false, _tokenId2);

        require(
            _source1.ownerOf(_tokenId1) != _source2.ownerOf(_tokenId2),
            "ERC721SwapRentAgreement: token 1 and token 2 have the same owner"
        );

        rentAgreement = RentAgreement(token1, token2, 0, _rentDuration, _rentExpirationTime, RentStatus.pending);
    }

    modifier onlyErc721Contracts() {
        Token memory token1 = rentAgreement.token1;
        Token memory token2 = rentAgreement.token2;
        require(
            (_msgSender() == address(token1.source) || (_msgSender() == address(token2.source))),
            "ERC721SwapRentAgreement: only registered erc721 can change state"
        );
        _;
    }

    function afterRentAgreementReplaced(uint256) public view override onlyErc721Contracts {
        require(
            rentAgreement.rentStatus == RentStatus.pending,
            "ERC721SwapRentAgreement: rent agreement already active"
        );
    }

    function startRent() public {
        // Before the expiration date.
        require(block.timestamp <= rentAgreement.rentExpirationTime, "ERC721SwapRentAgreement: rent expired");
        // Rent agreement has to be pending.
        require(
            rentAgreement.rentStatus == RentStatus.pending,
            "ERC721SwapRentAgreement: rent agreement already active"
        );

        Token memory token1 = rentAgreement.token1;
        Token memory token2 = rentAgreement.token2;

        // Tokens have to be aproved for rental by their owners or approvers.
        require(token1.approvedForRent, "ERC721SwapRentAgreement: token 1 not approved for rent");
        require(token2.approvedForRent, "ERC721SwapRentAgreement: token 2 not approved for rent");

        // Start the rent.
        rentAgreement.rentStatus = RentStatus.active;
        rentAgreement.startTime = uint40(block.timestamp);

        // Swap the tokens.
        token1.source.acceptRentAgreement(token2.source.ownerOf(token2.tokenId), token1.tokenId);
        token2.source.acceptRentAgreement(token1.source.rentedOwnerOf(token1.tokenId), token2.tokenId);
    }

    function afterRentStarted(address from, uint256) public view override onlyErc721Contracts {
        require(from == address(this));
    }

    function _isOwnerOrApprover(
        IERC721Rent source,
        uint256 tokenId,
        address owner,
        address target
    ) internal view returns (bool) {
        return (target == owner || target == source.getApproved(tokenId) || source.isApprovedForAll(owner, target));
    }

    function approveRent(IERC721Rent source, uint256 tokenId) external {
        Token memory token1 = rentAgreement.token1;
        Token memory token2 = rentAgreement.token2;

        // Only registered sources and tokenIds can be approved.
        require(
            (source == token1.source) || (source == token2.source),
            "ERC721SwapRentAgreement: token not registered"
        );
        require(
            (tokenId == token1.tokenId) || (tokenId == token2.tokenId),
            "ERC721SwapRentAgreement: invalid token id"
        );

        // Only tokenId owner or approver can approve the rent.
        require(
            _isOwnerOrApprover(source, tokenId, source.ownerOf(tokenId), _msgSender()),
            "ERC721SwapRentAgreement: only owner or approver can approve rent agreement"
        );

        // Clear tokens for rental.
        if (source == token1.source && tokenId == token1.tokenId) {
            token1.approvedForRent = true;
            rentAgreement.token1 = token1;
        } else {
            token2.approvedForRent = true;
            rentAgreement.token2 = token2;
        }
    }

    function stopRental() public {
        require(rentAgreement.rentStatus == RentStatus.active, "ERC721SwapRentAgreement: can only stop active rent");
        require(
            block.timestamp >= rentAgreement.startTime + rentAgreement.rentDuration,
            "ERC721SwapRentAgreement: rental period not finished yet"
        );

        // Reinitialize the tokens state.
        Token memory token1 = rentAgreement.token1;
        Token memory token2 = rentAgreement.token2;

        token1.approvedForRent = false;
        token2.approvedForRent = false;

        // Reinitialize the rent agreement.
        rentAgreement.token1 = token1;
        rentAgreement.token2 = token2;
        rentAgreement.startTime = 0;
        rentAgreement.rentStatus = RentStatus.pending;

        // Swap back the tokens.
        token1.source.stopRentAgreement(token1.tokenId);
        token2.source.stopRentAgreement(token2.tokenId);
    }

    function afterRentStopped(address from, uint256) public view override onlyErc721Contracts {
        require(address(this) == from);
    }
}
