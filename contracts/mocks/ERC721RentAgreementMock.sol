// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../token/ERC721/extensions/IERC721Rent.sol";

contract ERC721RentAgreementMock is IERC721RentAgreement {
    bool private _fail;
    bool private _failForOwner;

    // Interface
    function onChangeAgreement(uint256) external view override {
        require(!_fail, "Failed from agreement contract");
    }

    function onStartRent(uint256, address) external view override {
        require(!_fail, "Failed from agreement contract");
    }

    function onStopRent(uint256, RentingRole role) external view override {
        require(!_fail, "Failed from agreement contract");
        require(role == RentingRole.Renter || !_failForOwner, "Failed from agreement contract");
    }

    function supportsInterface(bytes4) external pure override returns (bool) {
        return true;
    }

    // For the test
    function setFail(bool fail) public {
        _fail = fail;
    }

    function setFailForOwner(bool fail) public {
        _failForOwner = fail;
    }
}
