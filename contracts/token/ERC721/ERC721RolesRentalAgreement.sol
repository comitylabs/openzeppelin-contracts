pragma solidity ^0.8.0;

import "../../utils/Context.sol";
import "./extensions/IERC721Roles.sol";
import "../../utils/introspection/ERC165.sol";

contract ERC721RolesRentalAgreement is Context, IERC721RolesManager, ERC165 {
    // The status of the rent
    enum RentalStatus {
        pending,
        active,
        finished
    }

    // A representation of rental agreement terms
    struct RentalAgreement {
        // The duration of the rent, in seconds
        uint32 rentalDuration;
        // The timestamp after which the rental agreement has expired and is no longer valid
        uint32 expirationDate;
        // The timestamp corresponding to the start of the rental period
        uint32 startTime;
        // The fees in wei that a renter needs to pay to start the rent
        uint256 rentalFees;
        RentalStatus rentalStatus;
    }

    // The ERC721Roles token for which this contract can be used as a roles manager
    IERC721Roles public erc721Contract;

    // Mapping from tokenId to rental agreement
    mapping(uint256 => RentalAgreement) public tokenIdToRentalAgreement;

    // Mapping addresses to balances
    mapping(address => uint256) public balances;

    // The identifier of the role Renter
    bytes4 public renterRoleId = bytes4(keccak256("ERC721Roles::Renter"));

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

    function afterRolesManagerRemoved(uint256 tokenId) external view onlyErc721Contract {
        RentalAgreement memory agreement = tokenIdToRentalAgreement[tokenId];
        require(
            agreement.rentalStatus != RentalStatus.active,
            "ERC721RolesRentalAgreement: can't remove the roles manager contract if there is an active rental"
        );
    }

    // Allow the token's owner or operator to set up a new rental agreement.
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

        RentalAgreement memory currentAgreement = tokenIdToRentalAgreement[tokenId];
        require(
            currentAgreement.rentalStatus != RentalStatus.active,
            "ERC721RolesRentalAgreement: can't update rental agreement if there is an active one already"
        );

        RentalAgreement memory rentalAgreement = RentalAgreement(
            duration,
            expirationDate,
            0,
            fees,
            RentalStatus.pending
        );
        // Set the rental agreement
        tokenIdToRentalAgreement[tokenId] = rentalAgreement;
    }

    // startRental allows an address to start the rent by paying the fees
    function startRental(address forAddress, uint256 tokenId) public payable {
        RentalAgreement memory rentalAgreement = tokenIdToRentalAgreement[tokenId];
        require(
            block.timestamp <= rentalAgreement.expirationDate,
            "ERC721RolesRentalAgreement: rental agreement expired"
        );
        require(
            rentalAgreement.rentalStatus != RentalStatus.active,
            "ERC721RolesRentalAgreement: rental already in progress"
        );

        uint256 rentalFees = rentalAgreement.rentalFees;
        require(msg.value >= rentalFees, "ERC721RolesRentalAgreement: value below the rental fees");

        address owner = erc721Contract.ownerOf(tokenId);
        // Credit the fees to the owner's balance
        balances[owner] += rentalFees;
        // Credit the remaining value to the sender's balance
        balances[_msgSender()] += msg.value - rentalFees;

        // Start the rental
        rentalAgreement.rentalStatus = RentalStatus.active;
        rentalAgreement.startTime = uint32(block.timestamp);

        // Reflect the role in the ERC721 token
        erc721Contract.addRole(forAddress, tokenId, renterRoleId);
    }

    // stopRental stops the rental
    function stopRental(address forAddress, uint256 tokenId) public {
        RentalAgreement memory rentalAgreement = tokenIdToRentalAgreement[tokenId];
        require(rentalAgreement.rentalStatus == RentalStatus.active, "ERC721RolesRentalAgreement: rental not active");
        require(
            block.timestamp - rentalAgreement.startTime >= rentalAgreement.rentalDuration,
            "ERC721RolesRentalAgreement: rental still ongoing"
        );

        // Stop the rental
        rentalAgreement.rentalStatus = RentalStatus.finished;

        // Revoke the renter's role
        erc721Contract.revokeRole(forAddress, tokenId, renterRoleId);
    }

    // afterRoleAdded will be called back in `erc721Contract.addRole`
    function afterRoleAdded(
        address fromAddress,
        address,
        uint256,
        bytes4
    ) external view onlyErc721Contract {
        require(fromAddress == address(this), "ERC721RolesRentalAgreement: only this contract can set up renter roles");
    }

    // afterRoleRevoked will be called back in `erc721Contract.revokeRole`
    function afterRoleRevoked(
        address fromAddress,
        address,
        uint256,
        bytes4
    ) external view onlyErc721Contract {
        require(fromAddress == address(this), "ERC721RolesRentalAgreement: only this contract can revoke renter roles");
    }

    function _isOwnerOrApproved(uint256 tokenId, address sender) internal view returns (bool) {
        address owner = erc721Contract.ownerOf(tokenId);
        return
            owner == sender ||
            erc721Contract.getApproved(tokenId) == sender ||
            erc721Contract.isApprovedForAll(owner, sender);
    }

    // Allow addresses to redeem their funds
    function redeemFunds(uint256 _value) public {
        require(_value <= balances[_msgSender()], "ERC721RolesRentalAgreement: not enough funds to redeem");

        balances[_msgSender()] -= _value;

        // Check if the transfer is successful.
        require(_attemptETHTransfer(_msgSender(), _value), "ERC721RolesRentalAgreement: ETH transfer failed");
    }

    function _attemptETHTransfer(address _to, uint256 _value) internal returns (bool) {
        // Here increase the gas limit a reasonable amount above the default, and try
        // to send ETH to the recipient.
        // NOTE: This might allow the recipient to attempt a limited reentrancy attack.
        (bool success, ) = _to.call{value: _value, gas: 30000}("");
        return success;
    }
}
