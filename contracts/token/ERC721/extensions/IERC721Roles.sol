// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../IERC721.sol";
import "../../../utils/introspection/IERC165.sol";

/// @title ERC721 token roles management interface
///
/// Defines the interface that a role management contract should support to be used by
/// `IERC721Roles`.
interface IERC721RolesManagement is IERC165 {

    /// Function called at the end of `IERC721Roles.setRolesManagement` on the roles management contract
    /// currently set for the token, if one exists.
    ///
    /// @dev Allows the roles management to cancel the change by reverting if it deems it
    /// necessary. The `IERC721Roles` is calling this function, so all information needed
    /// can be queried through the `msg.sender`. This event is only called when their are no specific roles 
    /// set as it is not allowed to change the role manager when there are active
    function afterRolesManagementRemoved() external;

    /// Function called at the end of `IERC721Roles.revokeRole` 
    /// 
    /// @dev Allows the roles management to cancel role withdrawal by reverting if it deems it
    /// necessary. The `IERC721Roles` is calling this function, so all information needed
    /// can be queried through the `msg.sender`. This event is not called if a rental is
    /// not in progress.
    function afterRoleRevoked(address forAddress, uint256 tokenId, bytes4 roleId) external;

    /// Function called at the end of `IERC721Roles.addRole`.
    ///
    /// @dev Allows the roles management to prevent adding a new role if it deems it
    /// necessary. The `IERC721Roles` is calling this function, so all information needed
    /// can be queried through the `msg.sender`.
    ///
    /// @param forAddress The address that called `IERC721Roles.addRole`
    function afterRoleAdded(address forAddress, uint256 tokenId, bytes4 roleId) external;
}

/// @title ERC721 token roles interface
///
/// Defines the optional interface that allows setting roles for users by tokenId. 
/// It delegates the logic of adding and revoking roles to a roles management contract implementing the 
/// `IERC721RolesManagement` interface.
/// A user can hold multiple roles and multiple users can be granted the same role. It's the 
/// responsability of the roles management contract to allow such interactions.
///
/// The roles manager is allowed to change the roles Management contract, 
/// if authorized by the currently set RoleManagement contract.
///
/// A role is defined similarly to functions' methodId by the first 4 bytes of its hash.
/// For example, the renter role will be defined by bytes4(sha3("renter"))

interface IERC721Roles is IERC721 {
    /// Set the role management contract.
    ///
    /// A previously set roles management contract must accept the change.
    /// The caller must be the roles manager, the address authorized make such a change
    ///
    /// @dev If a roles management was already set before this call, calls its
    /// `IERC721RolesManagement.afterRolesManagementRemoved` at the end of the call.
    ///
    /// @param rolesManagement The roles management contract. Set to 0 to remove the current roles management.
    function setRolesManagement(IERC721RolesManagement rolesManagement) external;

    /// @return the address of the roles management, or 0 if there is no roles management set.
    function rolesManagement() external returns (IERC721RolesManagement);

    /// Set the address authorized to change the roles management contract.
    /// @param rolesManager the new roles manager.
    function setRolesManager(address rolesManager) external;

    /// @return the roles manager.
    function rolesManager() external view returns(address);

    /// @return true if the role has been granted to the user.
    function roleGranted(address user, uint256 tokenId, bytes4 roleId) external view returns (bool);

    /// Set the role for the address and the token. 
    ///
    /// The token must have a roles management contract set.
    /// The roles management contract must accept the new role for the address
    ///
    /// @dev Calls `IERC721RolesManagement.afterRoleAdded` at the end of the call.
    function addRole(address forAddress, uint256 tokenId, bytes4 roleId) external;

    /// Revoke the role for the token and the address.
    ///
    /// The token must have a roles management contract set.
    /// The roles management contract must accept the role withdrawal for this address.
    ///
    /// @dev Calls `IERC721RolesManagement.afterRoleRevoked` at the end of the call.
    function revokeRole(address forAddress, uint256 tokenId, bytes4 roleId) external;
}
