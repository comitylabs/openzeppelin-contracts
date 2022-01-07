pragma solidity ^0.8.0;

import "../../utils/Context.sol";
import "./extensions/IERC721Rent.sol";
import "../../utils/introspection/ERC165.sol";

contract ERC721SwapRentalAgreement is Context, IERC721RentAgreement, ERC165 {
    enum RentalStatus {
        pending,
        active
    }

    struct Token {
        IERC721Rent source;
        bool approvedForRental;
        uint256 tokenId;
    }

    struct RentalAgreement {
        Token token1;
        Token token2;
        uint40 startTime;
        uint40 rentalDuration;
        uint40 rentalExpirationTime;
        RentalStatus rentalStatus;
    }

    RentalAgreement public rentalAgreement;

    constructor(
        IERC721Rent _source1,
        IERC721Rent _source2,
        uint256 _tokenId1,
        uint256 _tokenId2,
        uint40 _rentalDuration,
        uint40 _rentalExpirationTime
    ) {
        Token memory token1 = Token(_source1, false, _tokenId1);
        Token memory token2 = Token(_source2, false, _tokenId2);

        require(
            _source1.ownerOf(_tokenId1) != _source2.ownerOf(_tokenId2),
            "ERC721SwapRentalAgreement: token 1 and token 2 have the same owner"
        );

        rentalAgreement = RentalAgreement(
            token1,
            token2,
            0,
            _rentalDuration,
            _rentalExpirationTime,
            RentalStatus.pending
        );
    }

    modifier onlyErc721Contracts() {
        Token memory token1 = rentalAgreement.token1;
        Token memory token2 = rentalAgreement.token2;
        require(
            (_msgSender() == address(token1.source) || (_msgSender() == address(token2.source))),
            "ERC721SwapRentalAgreement: only registered erc721 can change state"
        );
        _;
    }

    function afterRentAgreementReplaced(uint256) public view override onlyErc721Contracts {
        require(
            rentalAgreement.rentalStatus == RentalStatus.pending,
            "ERC721SwapRentalAgreement: rental agreement already active"
        );
    }

    function startRental() public {
        // Before the expiration date.
        require(block.timestamp <= rentalAgreement.rentalExpirationTime, "ERC721SwapRentalAgreement: rental expired");
        // rental agreement has to be pending.
        require(
            rentalAgreement.rentalStatus == RentalStatus.pending,
            "ERC721SwapRentalAgreement: rental agreement already active"
        );

        Token memory token1 = rentalAgreement.token1;
        Token memory token2 = rentalAgreement.token2;

        // Tokens have to be aproved for rentalal by their owners or approvers.
        require(token1.approvedForRental, "ERC721SwapRentalAgreement: token 1 not approved for rental");
        require(token2.approvedForRental, "ERC721SwapRentalAgreement: token 2 not approved for rental");

        // Start the rental.
        rentalAgreement.rentalStatus = RentalStatus.active;
        rentalAgreement.startTime = uint40(block.timestamp);

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

    function approveRental(IERC721Rent source, uint256 tokenId) external {
        Token memory token1 = rentalAgreement.token1;
        Token memory token2 = rentalAgreement.token2;

        // Only registered sources and tokenIds can be approved.
        require(
            (source == token1.source) || (source == token2.source),
            "ERC721SwapRentalAgreement: token not registered"
        );
        require(
            (tokenId == token1.tokenId) || (tokenId == token2.tokenId),
            "ERC721SwapRentalAgreement: invalid token id"
        );

        // Only tokenId owner or approver can approve the rental.
        require(
            _isOwnerOrApprover(source, tokenId, source.ownerOf(tokenId), _msgSender()),
            "ERC721SwapRentalAgreement: only owner or approver can approve rental agreement"
        );

        // Clear tokens for rentalal.
        if (source == token1.source && tokenId == token1.tokenId) {
            token1.approvedForRental = true;
            rentalAgreement.token1 = token1;
        } else {
            token2.approvedForRental = true;
            rentalAgreement.token2 = token2;
        }
    }

    function stopRental() public {
        require(
            rentalAgreement.rentalStatus == RentalStatus.active,
            "ERC721SwapRentalAgreement: can only stop active rental"
        );
        require(
            block.timestamp >= rentalAgreement.startTime + rentalAgreement.rentalDuration,
            "ERC721SwapRentalAgreement: rental period not finished yet"
        );

        // Reinitialize the tokens state.
        Token memory token1 = rentalAgreement.token1;
        Token memory token2 = rentalAgreement.token2;

        token1.approvedForRental = false;
        token2.approvedForRental = false;

        // Reinitialize the rental agreement.
        rentalAgreement.token1 = token1;
        rentalAgreement.token2 = token2;
        rentalAgreement.startTime = 0;
        rentalAgreement.rentalStatus = RentalStatus.pending;

        // Swap back the tokens.
        token1.source.stopRentAgreement(token1.tokenId);
        token2.source.stopRentAgreement(token2.tokenId);
    }

    function afterRentStopped(address from, uint256) public view override onlyErc721Contracts {
        require(address(this) == from);
    }
}
