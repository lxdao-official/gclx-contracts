const { expect } = require('chai');
const { keccak256 } = require('ethers/lib/utils');
const { MerkleTree } = require('merkletreejs');
const { ethers } = require('hardhat');

describe('contract test - allowList with MerkleProof', function () {
  let Token;
  let hardhatToken;
  let owner;
  const baseURI = 'ipfs://QmYdoCeWfvgZVwyEJfFM537qWnM21qoWU64ihBZx9nLcyx';

  beforeEach(async function () {
    Token = await ethers.getContractFactory('GCLX');

    // create 1 owner, 1 account not in the allowlist, and 18 accouts in the allowlist (ethers.getSigners() returns 20 total)
    [owner, denyAccount, ...allowlistAccounts] = await ethers.getSigners();

    // build a merkle tree based on all 18 allowList addresses
    allowlistAddresses = allowlistAccounts.map((account) => account.address);
    leaves = allowlistAddresses.map((addr) => keccak256(addr));
    merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    root = merkleTree.getRoot();

    // contract initialization and set the merkle tree root of the allowlist
    hardhatToken = await Token.deploy(baseURI);
    await hardhatToken.setStatus(3);
    await hardhatToken.setMerkleRoot(root);
  });

  it('allowlistMintMerkleProof Test #1 - address is in the allowlist ', async function () {
    allowAccount = allowlistAccounts[0];
    proof = merkleTree.getHexProof(keccak256(allowAccount.address));
    await hardhatToken
      .connect(allowAccount)
      .allowlistMintMerkleProof(2, proof, {
        value: ethers.utils.parseEther('0.02'),
      });
  });

  it('allowlistMintMerkleProof Test #2 - address is not in the allowlist ', async function () {
    proof = merkleTree.getHexProof(keccak256(denyAccount.address));
    try {
      expect(
        await hardhatToken
          .connect(denyAccount)
          .allowlistMintMerkleProof(2, proof, {
            value: ethers.utils.parseEther('0.02'),
          })
      ).to.throw();
    } catch (e) {
      expect(e.message).to.contain('GCLX: Ni bu zai bai ming dan li');
    }
  });

  it('allowlistMintMerkleProof Test #3 - exceeded max allow list quota (hardcode of 2 in the contract) for this address ', async function () {
    allowAccount = allowlistAccounts[1];
    proof = merkleTree.getHexProof(keccak256(allowAccount.address));
    try {
      expect(
        await hardhatToken
          .connect(allowAccount)
          .allowlistMintMerkleProof(3, proof, {
            value: ethers.utils.parseEther('0.03'),
          })
      ).to.throw();
    } catch (e) {
      expect(e.message).to.contain('GCLX: Nin tai tan xin le');
    }

    // mint 1 out of 2
    await hardhatToken
      .connect(allowAccount)
      .allowlistMintMerkleProof(1, proof, {
        value: ethers.utils.parseEther('0.01'),
      });

    // can still mint since there is still 1 quota left
    await hardhatToken
      .connect(allowAccount)
      .allowlistMintMerkleProof(1, proof, {
        value: ethers.utils.parseEther('0.01'),
      });
  });

  it('allowlistMintMerkleProof Test #4 - user can call both allowlistMintMerkleProof and mint functions if status=started', async function () {
    await hardhatToken.setStatus(1);
    allowAccount = allowlistAccounts[2];
    proof = merkleTree.getHexProof(keccak256(allowAccount.address));

    // do a public mint of 1
    await hardhatToken
      .connect(allowAccount)
      .mint(1, { value: ethers.utils.parseEther('0.04') });

    // max 2 per address under public mint(), the next call should fail with zuo duo lia
    try {
      expect(
        await hardhatToken
          .connect(allowAccount)
          .mint(2, { value: ethers.utils.parseEther('0.04') })
      ).to.throw();
    } catch (e) {
      expect(e.message).to.contain('GCLX: Zui duo lia');
    }

    // the user can still call allowlistmint() as she is in the allowlist with quota of 2
    await hardhatToken
      .connect(allowAccount)
      .allowlistMintMerkleProof(2, proof, {
        value: ethers.utils.parseEther('0.02'),
      });

    // the next call should fail as the user has used up her allowlist quota
    try {
      expect(
        await hardhatToken
          .connect(allowAccount)
          .allowlistMintMerkleProof(1, proof, {
            value: ethers.utils.parseEther('0.04'),
          })
      ).to.throw();
    } catch (e) {
      expect(e.message).to.contain('GCLX: Ling guo le');
    }
  });

  it('allowlistMintMerkleProof Test #5 - not enought ETH ', async function () {
    allowAccount = allowlistAccounts[3];
    proof = merkleTree.getHexProof(keccak256(allowAccount.address));

    // the next call should fail as the user tries to mint below the PRICE
    try {
      expect(
        await hardhatToken
          .connect(allowAccount)
          .allowlistMintMerkleProof(2, proof, {
            value: ethers.utils.parseEther('0.01'),
          })
      ).to.throw();
    } catch (e) {
      expect(e.message).to.contain('GCLX: Mei duo gei ETH.');
    }
  });
});
