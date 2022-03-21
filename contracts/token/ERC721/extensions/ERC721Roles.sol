pragma solidity ^0.8.0;

import "../ERC721.sol";
import "./IERC721Roles.sol";

contract ERC721Roles is ERC721, IERC721Roles {
    // The address authorized to change the _roleManagement contract.
    address private _rolesManager;
    // The contract holding the logic defining the roles access.
    IERC721RolesManagement private _rolesManagement;
    // A record of the registered and active roles by tokenId.
    mapping(uint256 => mapping(address => mapping(bytes4 => bool))) private _tokenIdRegisteredRoles;

    constructor(string memory name_, string memory symbol_, address rolesManager_) ERC721(name_, symbol_){
        _rolesManager = rolesManager_;
    }

    /// @inheritdoc IERC721Roles
    function setRolesManager(address rolesManager_) external {
        require(_msgSender()==_rolesManager, "ERC721: caller is not the rolesManager");
        _rolesManager = rolesManager_;
    }

    /// @inheritdoc IERC721Roles
    function rolesManager() public view returns (address) {
        return _rolesManager;
    }

    /// @inheritdoc IERC721Roles
    function setRolesManagement(IERC721RolesManagement rolesManagement_) external {
        require(_msgSender()==_rolesManager, "ERC721: caller is not the rolesManager");
        if (address(_rolesManagement) != address(0)) {
            _rolesManagement.afterRolesManagementRemoved();
        }

        _rolesManagement = rolesManagement_;
    }

    /// @inheritdoc IERC721Roles
    function rolesManagement() public view returns (IERC721RolesManagement){
        return _rolesManagement;
    }

    /// @inheritdoc IERC721Roles
    function roleGranted(address user, uint256 tokenId, bytes4 roleId) external view returns (bool) {
        return _tokenIdRegisteredRoles[tokenId][user][roleId];
    }

    /// @inheritdoc IERC721Roles
    function addRole(address forAddress, uint256 tokenId, bytes4 roleId) external {
        _tokenIdRegisteredRoles[tokenId][forAddress][roleId] = true;
        // Callback to the roles management contract.
        _rolesManagement.afterRoleAdded(forAddress, tokenId, roleId);
    }

    /// @inheritdoc IERC721Roles
    function revokeRole(address forAddress, uint256 tokenId, bytes4 roleId) external {
        _tokenIdRegisteredRoles[tokenId][forAddress][roleId] = false;
        // Callback to the roles management contract.
        _rolesManagement.afterRoleRevoked(forAddress, tokenId, roleId);
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Roles).interfaceId || super.supportsInterface(interfaceId);
    }
}