// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../IERC721.sol";
import "../../../utils/introspection/IERC165.sol";

/// @title ERC721 token roles manager interface
///
/// Defines the interface that a roles manager contract should support to be used by
/// `IERC721Roles`.
interface IERC721RolesManager is IERC165 {
    /// Function called at the end of `IERC721Roles.setRolesManager` on the roles manager contract
    /// currently set for the token, if one exists.
    ///
    /// @dev Allows the roles manager to cancel the change by reverting if it deems it
    /// necessary. The `IERC721Roles` is calling this function, so all information needed
    /// can be queried through the `msg.sender`.
    function afterRolesManagerRemoved(uint256 tokenId) external;

    /// Function called at the end of `IERC721Roles.revokeRole`
    ///
    /// @dev Allows the roles manager to cancel role withdrawal by reverting if it deems it
    /// necessary. The `IERC721Roles` is calling this function, so all information needed
    /// can be queried through the `msg.sender`.
    /// @param fromAddress The address that called `IERC721Roles.revokeRole`
    function afterRoleRevoked(
        address fromAddress,
        address forAddress,
        uint256 tokenId,
        bytes4 roleId
    ) external;

    /// Function called at the end of `IERC721Roles.addRole`.
    ///
    /// @dev Allows the roles manager to prevent adding a new role if it deems it
    /// necessary. The `IERC721Roles` is calling this function, so all information needed
    /// can be queried through the `msg.sender`.
    ///
    /// @param fromAddress The address that called `IERC721Roles.addRole`
    function afterRoleAdded(
        address fromAddress,
        address forAddress,
        uint256 tokenId,
        bytes4 roleId
    ) external;
}

/// @title ERC721 token roles interface
///
/// Defines the optional interface that allows setting roles for users by tokenId.
/// It delegates the logic of adding and revoking roles to a roles manager contract implementing the
/// `IERC721RolesManager` interface.
/// A user could hold multiple roles and multiple users could be granted the same role. It's the
/// responsability of the roles manager contract to allow such permissions.
///
/// Only the token's owner or an approver is able to change the roles manager contract,
/// if authorized by the currently set RolesManager contract.
///
/// A role is defined similarly to functions' methodId by the first 4 bytes of its hash.
/// For example, the renter role will be defined by bytes4(keccak256("ERC721Roles::Renter"))

interface IERC721Roles is IERC721 {
    /// Set the roles manager contract for a token.
    ///
    /// A previously set roles manager contract must accept the change.
    /// The caller must be the token's owner or operator.
    ///
    /// @dev If a roles manager contract was already set before this call, calls its
    /// `IERC721RolesManager.afterRolesManagerRemoved` at the end of the call.
    ///
    /// @param rolesManager The roles manager contract. Set to 0 to remove the current roles manager.
    function setRolesManager(uint256 tokenId, IERC721RolesManager rolesManager) external;

    /// @return the address of the roles manager, or 0 if there is no roles manager set.
    function rolesManager(uint256 tokenid) external returns (IERC721RolesManager);

    /// @return true if the role has been granted to the user.
    function roleGranted(
        address user,
        uint256 tokenId,
        bytes4 roleId
    ) external view returns (bool);

    /// Set the role for the address and the token.
    ///
    /// The token must have a roles manager contract set.
    /// The roles manager contract must accept the new role for the address
    ///
    /// @dev Calls `IERC721RolesManager.afterRoleAdded` at the end of the call.
    function addRole(
        address forAddress,
        uint256 tokenId,
        bytes4 roleId
    ) external;

    /// Revoke the role for the token and the address.
    ///
    /// The token must have a roles manager contract set.
    /// The roles manager contract must accept the role withdrawal for this address.
    ///
    /// @dev Calls `IERC721RolesManager.afterRoleRevoked` at the end of the call.
    function revokeRole(
        address forAddress,
        uint256 tokenId,
        bytes4 roleId
    ) external;
}
