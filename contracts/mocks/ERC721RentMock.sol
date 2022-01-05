// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC721Mock.sol";
import "../token/ERC721/extensions/IERC721Rent.sol";

/**
 * @title ERC721SingleRentAgreementMock
 */
contract ERC721SingleRentMock is ERC721Mock {
    address public owner;
    mapping(uint256 => IERC721RentAgreement) public rentAgreements;

    constructor(string memory name, string memory symbol) ERC721Mock(name, symbol) {}

    function setRentAgreement(IERC721RentAgreement agreement, uint256 tokenId) public override {
        owner = _msgSender();
        rentAgreements[tokenId] = agreement;
    }

    function acceptRentAgreement(uint256 tokenId) public override {
        IERC721RentAgreement agreement = rentAgreements[tokenId];
        agreement.onStartRent(tokenId, _msgSender());
    }

    function stopRentAgreement(uint256 tokenId) public override {
        IERC721RentAgreement agreement = rentAgreements[tokenId];
        RentingRole role;
        if (_msgSender() == owner) {
            role = RentingRole.OwnerOrApprover;
        } else {
            role = RentingRole.Renter;
        }
        agreement.onStopRent(tokenId, role);
    }
}
