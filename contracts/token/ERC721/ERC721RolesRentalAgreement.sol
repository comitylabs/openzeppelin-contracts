pragma solidity ^0.8.0;

import "../../utils/Context.sol";
import "./extensions/IERC721Roles.sol";
import "../../utils/introspection/ERC165.sol";

contract ERC721RolesRentalAgreement is Context, IERC721RolesManagement, ERC165 {
    enum RentalStatus {
        pending,
        active,
        finished
    }

    struct RentalAgreement {
        uint32 rentalDuration;
        uint32 expirationDate;
        uint32 startTime;
        uint256 rentalFees;
        RentalStatus rentalStatus;
    }

    IERC721Roles public erc721Contract;
    mapping(uint256 => RentalAgreement) public tokenIdToRentalAgreement;
    uint256[] public tokenRented;

    // Mapping owners address to balances;
    mapping(address => uint256) public balances;

    bytes4 public renterRoleId = bytes4(keccak256("ERC721Role::Renter"));

    constructor(IERC721Roles _erc721Contract) {
        erc721Contract = _erc721Contract;
    }

    // ===== Modifiers ====== //
    modifier onlyErc721Contract() {
        require(
            _msgSender() == address(erc721Contract),
            "ERC721RolesRentalAgreement: only erc721Contract contract can modify state"
        );
        _;
    }

    function afterRolesManagementRemoved() external onlyErc721Contract {
        // The roles management contract can be updated only if all rentals are finished.
        for (uint256 i = 0; i < tokenRented.length; i++) {
            RentalStatus rentalStatus = tokenIdToRentalAgreement[tokenRented[i]].rentalStatus;
            require(rentalStatus == RentalStatus.finished, "ERC721RolesRentalAgreement: rental is still active");
        }
    }

    // Allow the token holder or operator to set up a new rental agreement.
    function setRentalAgreement(
        uint256 tokenId,
        uint32 duration,
        uint32 expirationDate,
        uint256 fees
    ) public {
        require(
            _isOwnerOrApproved(tokenId, _msgSender()),
            "ERC721RolesRentalAgreement: only owner or approver can set up a rental agreement"
        );

        RentalAgreement existing_agreement = tokenIdToRentalAgreement[token_id];
        require(
            existing_agreement.rentalStatus != RentalStatus.active,
            "ERC721RolesRentalAgreement: can't update rental agreement if there is an active one already"
        );

        RentalAgreement rentalAgreement = RentalAgreement(
            duration,
            expirationDate,
            uint32(block.timestamp),
            fees,
            RentalStatus.pending
        );
        tokenIdToRentalAgreement[token_id] = rentalAgreement;
    }

    function startRental(address forAddress, uint256 tokenId) public payable {
        RentalAgreement rentalAgreement = tokenIdToRentalAgreement[token_id];
        require(now <= rentalAgreement.expirationDate, "ERC721RolesRentalAgreement: rental agreement expired");
        require(
            rentalAgreement.rentalStatus != rentalStatus.active,
            "ERC721RolesRentalAgreement: rental already in progress"
        );

        uint256 rentalFees = rentalAgreement.rentalFees;
        require(msg.value >= rentalFees, "ERC721RolesRentalAgreement: value below the rental fees");

        address owner = erc721Contract.ownerOf(tokenId);
        // Credit the fees to the owner's balance.
        balances[owner] += rentalFees;
        // Credit the remaining value to the sender's balance.
        balances[_msgSender()] += msg.value - rentalFees;

        // Start the rental
        rentalAgreement.rentalStatus = RentalStatus.active;
        rentalAgreement.startTime = now;

        // Mark the token as rented.
        tokenRented.push(tokenId);

        // Reflect the role in the ERC721 token.
        erc721Contract.addRole(forAddress, tokenId, renterRoleId);
    }

    function stopRental(address forAddress, uint256 tokenId) public {
        RentalAgreement rentalAgreement = tokenIdToRentalAgreement[token_id];
        require(rentalAgreement.rentalStatus == rentalStatus.active, "ERC721RolesRentalAgreement: rental not active");
        require(
            now - rentalAgreement.startTime >= rentalAgreement.rentalDuration,
            "ERC721RolesRentalAgreement: rental still ongoing"
        );

        // Stop the rental
        rentalAgreement.rentalStatus = finished;

        // Revoke the renter role
        erc721Contract.revokeRole(forAddress, tokenId, renterRoleId);
    }

    function afterRoleAdded(
        address fromAddress,
        address forAddress,
        uint256 tokenId,
        bytes4 roleId
    ) external onlyErc721Contract {
        require(fromAddress == address(this), "ERC721RolesRentalAgreement: only this contract can set up renter roles");
    }

    function afterRoleRevoked(
        address fromAddress,
        address forAddress,
        uint256 tokenId,
        bytes4 roleId
    ) external onlyErc721Contract {
        require(fromAddress == address(this), "ERC721RolesRentalAgreement: only this contract can revoke renter roles");
    }

    function _isOwnerOrApproved(uint256 tokenId, address sender) internal view returns (bool) {
        address owner = erc721Contract.ownerOf(tokenId);
        return
            owner == sender ||
            erc721Contract.getApproved(tokenId) == sender ||
            erc721Contract.isApprovedForAll(owner, sender);
    }

    function redeemFunds(uint256 _value) public {
        require(_value <= balances[_msgSender()], "ERC721RolesRentalAgreement: not enough funds to redeem");

        balances[_msgSender()] -= _value;

        // Check if the transfer is successful.
        require(_attemptETHTransfer(_msgSender(), _value), "ERC721RolesRentalAgreement: ETH transfer failed");

        // Emit an event.
        emit FundsRedeemed(_msgSender(), _value, balances[_msgSender()]);
    }

    function _attemptETHTransfer(address _to, uint256 _value) internal returns (bool) {
        // Here increase the gas limit a reasonable amount above the default, and try
        // to send ETH to the recipient.
        // NOTE: This might allow the recipient to attempt a limited reentrancy attack.
        (bool success, ) = _to.call{value: _value, gas: 30000}("");
        return success;
    }
}
