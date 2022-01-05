const { BN, time, expectRevert } = require('@openzeppelin/test-helpers');
const { assert, expect } = require('chai');

const ERC721SingleRentMock = artifacts.require('ERC721SingleRentMock');
const ERC721SingleRentAgreement = artifacts.require('ERC721SingleRentAgreement');

const RENT_STATUS = {
  PENDING: 0,
  ACTIVE: 1,
  FINISHED: 2,
};

contract('ERC721SingleRentAgreement', function (accounts) {
  beforeEach(async function () {
    // Rental period.
    this.duration = new BN('604800'); // One week.
    this.exp = new BN('1814400'); // Three weeks.
    this.latestTime = await time.latest();
    this.expirationDate = this.latestTime.add(this.exp);

    // Fees.
    this.rentalFees = new BN('10000');

    // Accounts.
    [this.owner, this.renter] = accounts;

    // Erc721 contracts
    this.name = 'Non Fungible Token';
    this.symbol = 'NFT';
    this.erc721Rent = await ERC721SingleRentMock.new(this.name, this.symbol);
    this.erc721RentAddress = this.erc721Rent.address;
    this.tokenId = new BN('12345');

    // Initialize a new contract.
    this.erc721SingleRentAgreement = await ERC721SingleRentAgreement.new(
      this.owner,
      this.renter,
      this.erc721RentAddress,
      this.duration,
      this.expirationDate,
      this.rentalFees,
    );

    // Set Rent agreement.
    await this.erc721Rent.setRentAgreement(this.erc721SingleRentAgreement.address, this.tokenId, { from: this.owner });
  });

  context('Start Rent', async function () {
    it('contract initial is pending', async function () {
      const status = await this.erc721SingleRentAgreement.rentStatus.call();
      expect(status.toString()).to.equal(RENT_STATUS.PENDING.toString());
    });

    it('Only erc721 contract can update state', async function () {
      await expectRevert(this.erc721SingleRentAgreement.onChangeAgreement(this.tokenId, { from: this.renter }),
        'Only erc721Contract contract can modify rent agreement state');
    });

    it('Cannot start rent if rent not paid', async function () {
      await expectRevert(
        this.erc721Rent.acceptRentAgreement(this.tokenId, { from: this.renter }),
        'Rent has to be paid first');
    });

    it('Wrong rent fees', async function () {
      // Pay rent with wrong fee amount.
      await expectRevert(this.erc721SingleRentAgreement.payRent({ from: this.renter, value: this.rentalFees + 1 }),
        'Wrong rental fees amount');
    });

    it('Enable to start rent after rent is paid', async function () {
      // Pay rent.
      await this.erc721SingleRentAgreement.payRent({ from: this.renter, value: this.rentalFees });
      const rentPaid = await this.erc721SingleRentAgreement.rentPaid();
      assert.equal(rentPaid, true);

      // Assert rent is active.
      await this.erc721Rent.acceptRentAgreement(this.tokenId, { from: this.renter });
      const status = await this.erc721SingleRentAgreement.rentStatus();
      expect(status.toString()).to.equal(RENT_STATUS.ACTIVE.toString());
    });

    it('Enable to change agreement when pending and not paid', async function () {
      await this.erc721SingleRentAgreement.onChangeAgreement(this.tokenId, { from: this.erc721RentAddress });
    });

    it('Cannot change agreement after the rent has been paid', async function () {
      // Pay rent.
      await this.erc721SingleRentAgreement.payRent({ from: this.renter, value: this.rentalFees });
      await expectRevert(
        this.erc721SingleRentAgreement.onChangeAgreement(this.tokenId, { from: this.erc721RentAddress }), 'Rent already paid');
    });

    it('Cannot start rent after expiration date', async function () {
      await time.increase(1814400); // Increase ganache time by 3 weeks.

      // Pay rent.
      await this.erc721SingleRentAgreement.payRent({ from: this.renter, value: this.rentalFees });
      const rentPaid = await this.erc721SingleRentAgreement.rentPaid();
      assert.equal(rentPaid, true);

      // Assert cannot start rent after expiration date.
      await expectRevert(
        this.erc721SingleRentAgreement.onStartRent.call(this.tokenId, this.renter, { from: this.erc721RentAddress }),
        'rental agreement expired',
      );
    });
  });

  const startRent = async function (agreement, renter, fees, erc721Rent, tokenId) {
    // Pay rent.
    await agreement.payRent({ from: renter, value: fees });
    // Start rent.
    await erc721Rent.acceptRentAgreement(tokenId, { from: renter });
  };

  context('Finish rent', async function () {
    it('Owner cannot finish rent before the rental period is over', async function () {
      await startRent(this.erc721SingleRentAgreement, this.renter, this.rentalFees, this.erc721Rent, this.tokenId);
      await expectRevert(this.erc721Rent.stopRentAgreement(this.tokenId, { from: this.owner }), 'Rental period not finished yet');
    });

    it('Renter is able to finish rent before the rental period is over', async function () {
      await startRent(this.erc721SingleRentAgreement, this.renter, this.rentalFees, this.erc721Rent, this.tokenId);
      await this.erc721Rent.stopRentAgreement(this.tokenId, { from: this.renter });
    });
  });
});
