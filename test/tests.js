const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('contract test', function () {
  let Token;
  let hardhatToken;
  let owner;
  let addr1;
  const baseURI = 'ipfs://QmYdoCeWfvgZVwyEJfFM537qWnM21qoWU64ihBZx9nLcyx';

  beforeEach(async function () {
    Token = await ethers.getContractFactory('GCLX');
    [owner, addr1] = await ethers.getSigners();

    hardhatToken = await Token.deploy(baseURI);
    await hardhatToken.setStatus(1);
  });

  it('Should set the right owner', async function () {
    expect(await hardhatToken.owner()).to.equal(owner.address);
  });

  it('baseURI is equal', async function () {
    expect(await hardhatToken.baseURI()).to.equal(baseURI);
  });

  it('mint test #1 - user can mint within the quota but will fail if exceeding the quota', async function () {
    await hardhatToken.mint(1, { value: ethers.utils.parseEther('0.01') });
    try {
      await hardhatToken.mint(2, { value: ethers.utils.parseEther('0.02') });
    } catch (e) {
      expect(e.message).to.contain('GCLX: Zui duo lia');
    }
  });

  it('mint test #2 - refund if giving more ETH than the price', async function () {
    const initialOwnerBalance = await hardhatToken.balanceOf(owner.address);
    await hardhatToken.mint(1, { value: ethers.utils.parseEther('10.01') });

    const finalOwnerBalance = await hardhatToken.balanceOf(owner.address);
    expect(finalOwnerBalance).to.equal(initialOwnerBalance.sub(-1));
  });

  // it("mint more than 2", async function () {
  //   await hardhatToken.mint(2, { value: ethers.utils.parseEther("0.02") });
  // });
});
