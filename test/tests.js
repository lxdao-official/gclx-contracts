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

  it('mint ', async function () {
    await hardhatToken.mint(1, { value: ethers.utils.parseEther('0.04') });
    try{
    await hardhatToken.mint(2, { value: ethers.utils.parseEther('0.02') });
    }
    catch(e){
      expect(e.message).to.contain("GCLX: Zui duo lia")
    }
   });

  it('allowlistMint Test #1 - exceeded max number for this address ', async function () {
    await hardhatToken.setStatus(3);
    await hardhatToken.seedAllowlist([owner.address],[3])
    try{
      expect(await hardhatToken.allowlistMint(4, { value: ethers.utils.parseEther('0.04') })).to.throw();
    } catch(e){
      expect(e.message).to.contain("GCLX: Nin tai tan xin le")
    }
  });

  it('allowlistMint Test #2 - should work ', async function () {
    await hardhatToken.setStatus(3);
    await hardhatToken.seedAllowlist([owner.address],[4])
    await hardhatToken.allowlistMint(4, { value: ethers.utils.parseEther('0.04') });
  });

  it('allowlistMint Test #3 - not in allowlist', async function () {
    await hardhatToken.setStatus(3);
    try{
      expect(await hardhatToken.allowlistMint(2, { value: ethers.utils.parseEther('0.04') })).to.throw();
    }
    catch(e){
      expect(e.message).to.contain("GCLX: Ni bu zai bai min dan li")
    }
  });

  it('allowlistMint Test #4 - can not public mint if allowlistonly', async function () {
    await hardhatToken.setStatus(3);
    try{
      expect(await hardhatToken.mint(1, { value: ethers.utils.parseEther('0.04') })).to.throw();
    }
    catch(e){
      expect(e.message).to.contain("GCLX: Hai mei kai shi")
    }
  });

  it('allowlistMint Test #5 - user can call both allowlistMint and mint functions if status=started', async function () {
    await hardhatToken.setStatus(1);
    await hardhatToken.seedAllowlist([owner.address],[4])
    await hardhatToken.mint(1, { value: ethers.utils.parseEther('0.04') });
    // max 2 per address under public mint(), the next call should fail with zuo duo lia
    try{
      expect(await hardhatToken.mint(2, { value: ethers.utils.parseEther('0.04') })).to.throw();
    }
    catch(e){
      expect(e.message).to.contain("GCLX: Zui duo lia")
    }
    // the user can still call allowlistmint() as she is in the allowlist with limit of 4
    await hardhatToken.allowlistMint(4, { value: ethers.utils.parseEther('0.04') });
    // the next call should fail as the user has used up her allowlist quota, and is considered removed from allowlist
    try{
      expect(await hardhatToken.allowlistMint(2, { value: ethers.utils.parseEther('0.04') })).to.throw();
    }
    catch(e){
      expect(e.message).to.contain("GCLX: Ni bu zai bai min dan li")
    }
  });

  // it("mint more than 2", async function () {
  //   await hardhatToken.mint(2, { value: ethers.utils.parseEther("0.02") });
  // });
});
