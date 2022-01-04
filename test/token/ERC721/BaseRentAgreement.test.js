const { BN, time } = require('@openzeppelin/test-helpers');

const ERC721Mock = artifacts.require('ERC721Mock');
const BaseRentAgreement = artifacts.require('BaseRentAgreement');

contract('BaseRentAgreement', async function (accounts) {
  // One week.
  const duration = new BN('604800');

  // Two weeks.
  const exp = new BN(1209600);
  const latestTime = await time.latest();
  const expirationDate = latestTime.add(exp);
  const rentalFees = new BN('10000');
  const owner = accounts[0];
  const renter = accounts[1];
  const erc721Contract = await ERC721Mock.new();
  const erc721Address = await erc721Contract.deployed();

  beforeEach(async function () {
    // Initialize a new contract.
    this.baseRentAgreement = BaseRentAgreement(
      owner,
      renter,
      erc721Address,
      duration,
      expirationDate,
      rentalFees,
    );
  });

  context('test', function () {
    it('blah', async () => {
      console.log(this.baseRentAgreement);
    });
    it('contract initial state', async () => {
      assert.equal(this.baseRentAgreement.rentStatus, this.baseRentAgreement.RentStatuspending);
    });
  });
});
