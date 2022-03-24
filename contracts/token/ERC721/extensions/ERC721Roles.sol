pragma solidity ^0.8.0;

import "../ERC721.sol";
import "./IERC721Roles.sol";

abstract contract ERC721Roles is ERC721, IERC721Roles {
    // Mapping from token ID to roles management contract
    mapping(uint256 => IERC721RolesManager) private _rolesManager;

    // A record of the registered and active roles by tokenId
    mapping(uint256 => mapping(address => mapping(bytes4 => bool))) private _tokenIdRegisteredRoles;

    /// @inheritdoc IERC721Roles
    function setRolesManager(uint256 tokenId, IERC721RolesManager tokenRolesManager) external {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721Roles: only owner or approver can change roles manager"
        );

        // If there is an existing roles manager contract, call `IERC721RolesManager.afterRolesManagerRemoved`
        IERC721RolesManager currentRolesManager = _rolesManager[tokenId];
        if (address(currentRolesManager) != address(0)) {
            currentRolesManager.afterRolesManagerRemoved(tokenId);
        }

        // Update the roles manager contrac
        _rolesManager[tokenId] = tokenRolesManager;
    }

    /// @inheritdoc IERC721Roles
    function rolesManager(uint256 tokenId) public view returns (IERC721RolesManager) {
        return _rolesManager[tokenId];
    }

    /// @inheritdoc IERC721Roles
    function roleGranted(
        address user,
        uint256 tokenId,
        bytes4 roleId
    ) external view returns (bool) {
        return _tokenIdRegisteredRoles[tokenId][user][roleId];
    }

    /// @inheritdoc IERC721Roles
    function grantRole(
        address forAddress,
        uint256 tokenId,
        bytes4 roleId
    ) external {
        IERC721RolesManager manager = _rolesManager[tokenId];
        require(address(manager) != address(0), "ERC721Roles: no roles manager set up");

        // Register the new role
        _tokenIdRegisteredRoles[tokenId][forAddress][roleId] = true;

        // Callback to the roles manager contract
        manager.afterRoleGranted(_msgSender(), forAddress, tokenId, roleId);
    }

    /// @inheritdoc IERC721Roles
    function revokeRole(
        address forAddress,
        uint256 tokenId,
        bytes4 roleId
    ) external {
        IERC721RolesManager manager = _rolesManager[tokenId];
        require(address(manager) != address(0), "ERC721Roles: no roles manager set up");

        // De-register the role
        _tokenIdRegisteredRoles[tokenId][forAddress][roleId] = false;

        // Callback to the roles manager contract
        manager.afterRoleRevoked(_msgSender(), forAddress, tokenId, roleId);
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Roles).interfaceId || super.supportsInterface(interfaceId);
    }
}
