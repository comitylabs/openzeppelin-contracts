// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ERC20/IERC20.sol";
import "./IERC721.sol";
import "./extensions/IERC721Rental.sol";
import "../../utils/introspection/ERC165.sol";

/// Assumed partial interface of the Axie slp contract
interface AxieSlp is IERC20 {
    // We assume claim will revert when the token is rented if it is not called by this contract
    function claim(
        address owner,
        uint256 tokenId,
        uint256 amount,
        bytes calldata signature
    ) external;

    function claimAmount(address owner, uint256 tokenId) external view returns (uint256);
}

/// @title ERC721 scholarship agreement
///
contract ERC721ScholarshipAgreement is IERC721RentalAgreement, ERC165 {
    struct TokenParam {
        address scholar;
        uint24 scholarAmountPerMille; // the amount the scholar will get if the claim is 1000
    }

    mapping(IERC721Rental => mapping(uint256 => TokenParam)) public scholarTokens;
    AxieSlp public immutable slpContract;

    constructor(AxieSlp _slpContract) {
        slpContract = _slpContract;
    }

    /// @inheritdoc IERC721RentalAgreement
    function afterAgreementRemoved(uint256 tokenId) external view virtual override {
        // We do nothing here, it cannot be removed during a rental
    }

    /// @inheritdoc IERC721RentalAgreement
    function afterRentalStarted(address from, uint256 tokenId) external virtual override {
        IERC721Rental tokenHolder = IERC721Rental(msg.sender);
        TokenParam memory param = scholarTokens[tokenHolder][tokenId];

        require(
            tokenHolder.ownerOf(tokenId) == scholarTokens[tokenHolder][tokenId].scholar,
            "ERC721ScholarshipAgreement: scholar was not approved"
        );
        require(
            from == param.scholar || _isOwnerOrApproved(tokenHolder, tokenId, from),
            "ERC721ScholarshipAgreement: only renter, owner or their approved one can start a rental"
        );
        require(
            slpContract.claimAmount(tokenHolder.rentedOwnerOf(tokenId), tokenId) == 0,
            "ERC721ScholarshipAgreement: claim SLP before starting rental"
        );
    }

    /// @inheritdoc IERC721RentalAgreement
    function afterRentalStopped(address from, uint256 tokenId) external view virtual override {
        IERC721Rental tokenHolder = IERC721Rental(msg.sender);
        TokenParam memory param = scholarTokens[tokenHolder][tokenId];

        require(param.scholar != address(0), "ERC721ScholarshipAgreement: token was not rented");
        require(
            from == param.scholar || _isOwnerOrApproved(tokenHolder, tokenId, from),
            "ERC721ScholarshipAgreement: only renter, owner or their approved one can stop a rental"
        );
        require(
            slpContract.claimAmount(tokenHolder.ownerOf(tokenId), tokenId) == 0,
            "ERC721ScholarshipAgreement: call claim() first"
        );
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC721RentalAgreement).interfaceId || super.supportsInterface(interfaceId);
    }

    function setTokenScholar(
        IERC721Rental tokenHolder,
        address scholar,
        uint256 tokenId,
        uint24 scholarAmountPerMille
    ) external {
        require(
            tokenHolder.supportsInterface(type(IERC721Rental).interfaceId),
            "ERC721ScholarshipAgreement: contract does not support rental interface"
        );
        require(
            _isOwnerOrApproved(tokenHolder, tokenId, msg.sender),
            "ERC721ScholarshipAgreement: only owner or approved can set scholars"
        );
        require(
            tokenHolder.rentedOwnerOf(tokenId) == address(0),
            "ERC721ScholarshipAgreement: scholar cannot be changed during rental"
        );
        require(
            scholarAmountPerMille <= 1000,
            "ERC721ScholarshipAgreement: amount per mille cannot be bigger than 1000"
        );

        scholarTokens[tokenHolder][tokenId] = TokenParam(scholar, scholarAmountPerMille);
    }

    function claim(
        IERC721Rental tokenHolder,
        uint256 tokenId,
        bytes calldata signature
    ) external {
        address owner = tokenHolder.rentedOwnerOf(tokenId);
        require(owner != address(0), "ERC721ScholarshipAgreement: token is not rented");

        TokenParam memory params = scholarTokens[tokenHolder][tokenId];
        require(params.scholar != address(0), "ERC721ScholarshipAgreement: token is not rented through this contract");

        uint256 amount = slpContract.claimAmount(owner, tokenId);
        if (amount == 0) {
            return;
        }

        slpContract.claim(owner, tokenId, amount, signature);

        uint256 renterAmount = (params.scholarAmountPerMille * amount) / 1000;
        slpContract.transferFrom(owner, params.scholar, renterAmount);
    }

    function _isOwnerOrApproved(
        IERC721Rental holder,
        uint256 tokenId,
        address sender
    ) internal view returns (bool) {
        // We want the real owner here, not the renter
        address owner = holder.rentedOwnerOf(tokenId);
        if (owner == address(0)) {
            owner = holder.ownerOf(tokenId);
        }
        return owner == sender || holder.getApproved(tokenId) == sender || holder.isApprovedForAll(owner, sender);
    }
}
