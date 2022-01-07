const { BN, time, expectRevert } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const ERC721Mock = artifacts.require('ERC721Mock');
const ERC721SwapRentAgreement = artifacts.require('ERC721SwapRentAgreement');

const RENT_STATUS = {
  PENDING: 0,
  ACTIVE: 1,
};

contract('ERC721SwapRentAgreement', function (accounts) {
  before(async function () {
    // Accounts.
    [this.owner1, this.owner2, this.otherAccount] = accounts;

    // Token1 contract.
    this.name1 = 'Non Fungible Token 1';
    this.symbol1 = 'NFT1';
    this.token1 = await ERC721Mock.new(this.name1, this.symbol1);
    this.tokenId1 = new BN('1');
    await this.token1.mint(this.owner1, this.tokenId1);

    // Token2 contract.
    this.name2 = 'Non Fungible Token 2';
    this.symbol2 = 'NFT2';
    this.token2 = await ERC721Mock.new(this.name2, this.symbol2);
    this.tokenId2 = new BN('2');
    await this.token2.mint(this.owner2, this.tokenId2);

    // Non registered token.
    this.name3 = 'Non Fungible Token 3';
    this.symbol3 = 'NFT3';
    // Mint the same token id for owner2 in the non registered contract.
    // That will make pass the requires in the `setRentAgreement` function.
    this.nonRegisteredToken = await ERC721Mock.new(this.name3, this.symbol3);
    await this.nonRegisteredToken.mint(this.owner2, this.tokenId2);

    // Rental period.
    this.rentDuration = new BN('604800'); // One week.
    this.expireDuration = new BN('1209600'); // Tow weeks.
    this.latestTime = await time.latest();
    this.expirationDate = await this.latestTime.add(this.expireDuration);

    // Initialize a new swap rental contract.
    this.erc721SwapRentAgreement = await ERC721SwapRentAgreement.new(
      this.token1.address,
      this.token2.address,
      this.tokenId1,
      this.tokenId2,
      this.rentDuration,
      this.expirationDate,
    );

    // Set Rent agreement.
    await this.token1.setRentAgreement(this.erc721SwapRentAgreement.address, this.tokenId1, { from: this.owner1 });
    await this.token2.setRentAgreement(this.erc721SwapRentAgreement.address, this.tokenId2, { from: this.owner2 });
    await this.nonRegisteredToken.setRentAgreement(this.erc721SwapRentAgreement.address, this.tokenId2, {
      from: this.owner2,
    });
  });

  context('Initial state', async function () {
    it('Initial state is pending', async function () {
      const rentAgreement = await this.erc721SwapRentAgreement.rentAgreement();
      expect(rentAgreement.rentStatus.toNumber()).to.equal(RENT_STATUS.PENDING);
    });

    it('Only registered contracts can modify agreement', async function () {
      // Can't start rent agreement if not registered contract.
      await expectRevert(
        this.nonRegisteredToken.acceptRentAgreement(this.owner1, this.tokenId2, {
          from: this.owner2,
        }),
        'ERC721SwapRentAgreement: only registered erc721 can change state',
      );
    });
  });
  context('start rent', async function () {
    it('cannot approve rent on non registered tokens', async function () {
      await expectRevert(
        this.erc721SwapRentAgreement.approveRent(this.nonRegisteredToken.address, this.tokenId1, {
          from: this.owner1,
        }),
        'ERC721SwapRentAgreement: token not registered',
      );

      const newTokenId = new BN('4');
      await expectRevert(
        this.erc721SwapRentAgreement.approveRent(this.token1.address, newTokenId, { from: this.owner1 }),
        'ERC721SwapRentAgreement: invalid token id',
      );
    });
    it('approve rent', async function () {
      await this.erc721SwapRentAgreement.approveRent(this.token1.address, this.tokenId1, { from: this.owner1 });

      // Token 1 have been cleared for approval.
      const rentAgreement = await this.erc721SwapRentAgreement.rentAgreement();
      expect(rentAgreement.token1.approvedForRent).to.equal(true);

      expectRevert(
        this.erc721SwapRentAgreement.startRent({ from: this.owner1 }),
        'ERC721SwapRentAgreement: token 2 not approved for rent',
      );
    });

    it('start rent', async function () {
      await this.erc721SwapRentAgreement.approveRent(this.token2.address, this.tokenId2, { from: this.owner2 });
      // Registered tokens have been cleared for approval.
      let rentAgreement = await this.erc721SwapRentAgreement.rentAgreement();
      expect(rentAgreement.token2.approvedForRent).to.equal(true);

      // Start rent.
      await this.erc721SwapRentAgreement.startRent({ from: this.otherAccount });
      rentAgreement = await this.erc721SwapRentAgreement.rentAgreement();
      expect(rentAgreement.rentStatus.toNumber()).to.equal(RENT_STATUS.ACTIVE);
    });
  });

  context('Stop rent', async function () {
    it('Cannot finish rent before the rental period is over', async function () {
      await expectRevert(
        this.erc721SwapRentAgreement.stopRental({ from: this.owner1 }),
        'ERC721SwapRentAgreement: rental period not finished yet',
      );
    });

    it('finish rent', async function () {
      await time.increase(1209600); // Increase Ganache time by 2 weeks.
      await this.erc721SwapRentAgreement.stopRental({ from: this.owner1 });
      const rentAgreement = await this.erc721SwapRentAgreement.rentAgreement();
      expect(rentAgreement.rentStatus.toNumber()).to.equal(RENT_STATUS.PENDING);
      expect(rentAgreement.token1.approvedForRent).to.equal(false);
      expect(rentAgreement.token2.approvedForRent).to.equal(false);
    });
  });

  context('Rent expired', async function () {
    it('Cannot start rental period if rent expired', async function () {
      // Re-approve the rent.
      await this.erc721SwapRentAgreement.approveRent(this.token1.address, this.tokenId1, { from: this.owner1 });
      await this.erc721SwapRentAgreement.approveRent(this.token2.address, this.tokenId2, { from: this.owner2 });

      // Increase time.
      await time.increase(1814400); // Increase Ganache time by 3 weeks.
      await expectRevert(
        this.erc721SwapRentAgreement.startRent({ from: this.otherAccount }),
        'ERC721SwapRentAgreement: rent expired',
      );
    });
  });
});
