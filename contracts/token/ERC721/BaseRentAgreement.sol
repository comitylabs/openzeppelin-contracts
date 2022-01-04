pragma solidity ^0.8.0;

import "./IERC721Rent.sol";

contract BaseRentAgreement {
    enum RentStatus {
        pending,
        active,
        finished
    }

    struct RentAgreement {
        // Authorized renter.
        address renter;
        address owner;
        address nftRentAgreement;
        uint256 rentDuration;
        uint256 expirationDate;
        uint256 startTime;
        uint256 rentalFees;
        RentStatus rentStatus;
    }

    // Mapping owner address to balances;
    mapping(address => uint256) private _balances;
    bool _rentPaid;

    RentAgreement public rentAgreement;

    // ====== Events ====== //.

    event RentStatusChanged(
        address owner,
        address renter,
        uint256 tokenId,
        uint256 timestamp,
        RentStatus oldStatus,
        RentStatus newStatus
    );

    event RentPayment(address owner, address renter, uint256 amount);
    event FundsRedeemed(address redeemer, uint256 amount, uint256 remainingBalance);

    constructor(
        address _renter,
        address _nftRentAgreement,
        uint256 _duration,
        uint256 _expirationDate,
        uint256 _rentalFees
    ) {
        rentAgreement.owner = msg.sender;
        rentAgreement.renter = _renter;
        rentAgreement.nftRentAgreement = _nftRentAgreement;
        rentAgreement.rentDuration = _duration;
        rentAgreement.expirationDate = _expirationDate;
        rentAgreement.rentalFees = _rentalFees;
    }

    // ===== Modifiers ====== //
    modifier onlyNftRentAgreement() {
        require(
            msg.sender == rentAgreement.nftRentAgreement,
            "Only NftRentAgreement contract can modify rent agreement state"
        );
        _;
    }

    // Called when an owner of an NFT changes or removes its NTF renting contract.
    function onChangeAgreement(int256) public view onlyNftRentAgreement {
        require(rentAgreement.rentStatus == RentStatus.pending, "Rent agreement has to be pending to be updated.");
        require(!_rentPaid, "Rent already paid");
    }

    // Called when an account accepts a renting contract and wants to start the location.
    function onStartRent(uint256 tokenId, address tokenRenter) public onlyNftRentAgreement {
        require(rentAgreement.renter == tokenRenter, "Wrong renter.");
        require(rentAgreement.rentStatus == RentStatus.pending, "Rent status has to be pending.");
        require(_rentPaid, "Rent has to be paid first.");
        require(block.timestamp <= rentAgreement.expirationDate, "rental agreement expired.");

        rentAgreement.rentStatus = RentStatus.active;
        rentAgreement.startTime = block.timestamp;

        // Emit an event.
        emit RentStatusChanged(
            rentAgreement.owner,
            tokenRenter,
            tokenId,
            rentAgreement.startTime,
            RentStatus.pending,
            RentStatus.active
        );
    }

    function payRent() public payable {
        require(msg.sender == rentAgreement.renter, "Renter has to pay the rental fees.");
        require(msg.value == rentAgreement.rentalFees, "Wrong rental fees amount.");
        require(!_rentPaid, "Rent already paid.");

        _rentPaid = true;
        _balances[rentAgreement.owner] += msg.value;

        // Emit event.
        emit RentPayment(rentAgreement.owner, rentAgreement.renter, msg.value);
    }

    // Called when the owner or the renter wants to stop an active rent agreement.
    function onStopRent(uint256 tokenId, RentingRole role) public onlyNftRentAgreement {
        require(rentAgreement.rentStatus == RentStatus.active, "Rent status has to be active");
        rentAgreement.rentStatus = RentStatus.finished;

        if (role == RentingRole.Renter) {
            _stopRentRenter();
        } else {
            _stopRentOwner();
        }

        // Emit an event.
        emit RentStatusChanged(
            rentAgreement.owner,
            rentAgreement.renter,
            tokenId,
            rentAgreement.startTime,
            RentStatus.active,
            RentStatus.finished
        );
    }

    function _stopRentRenter() private {
        // Early rent termination.
        if (rentAgreement.startTime + rentAgreement.rentDuration >= block.timestamp) {
            uint256 _rentalPeriod = block.timestamp - rentAgreement.startTime;
            uint256 _newRentalFees = _rentalPeriod / rentAgreement.rentDuration;

            // Update the balances to reflect the rental period.
            _balances[rentAgreement.renter] = rentAgreement.rentalFees - _newRentalFees;
            _balances[rentAgreement.owner] = _newRentalFees;
        }
    }

    function _stopRentOwner() private view {
        // Owner can't do early rent termination.
        require(
            rentAgreement.startTime + rentAgreement.rentDuration <= block.timestamp,
            "Rental period not finished yet"
        );
    }

    function redeemFunds(uint256 _value) public {
        require(rentAgreement.rentStatus == RentStatus.finished, "Rent has to be finished to redeem funds");

        uint256 _balance = _balances[msg.sender];
        require(_value <= _balance, "Not enough funds to redeem");
        _balances[msg.sender] -= _value;

        // Check if the transfer is successful.
        require(_attemptETHTransfer(msg.sender, _value), "ETH transfer failed");

        // Emit an event.
        emit FundsRedeemed(msg.sender, _value, _balances[msg.sender]);
    }

    function _attemptETHTransfer(address _to, uint256 _value) internal returns (bool) {
        // Here increase the gas limit a reasonable amount above the default, and try
        // to send ETH to the recipient.
        // NOTE: This might allow the recipient to attempt a limited reentrancy attack.
        (bool success, ) = _to.call{value: _value, gas: 30000}("");
        return success;
    }
}
