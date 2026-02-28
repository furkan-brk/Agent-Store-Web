const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AgentStoreCredits", function () {
  let credits, owner, user1, user2, minter;

  beforeEach(async () => {
    [owner, user1, user2, minter] = await ethers.getSigners();
    const Credits = await ethers.getContractFactory("AgentStoreCredits");
    credits = await Credits.deploy();
  });

  describe("registerUser", () => {
    it("grants 100 initial credits on first registration", async () => {
      await credits.registerUser(user1.address);
      expect(await credits.balanceOf(user1.address)).to.equal(100n);
    });

    it("does not double-grant credits on second call", async () => {
      await credits.registerUser(user1.address);
      await credits.registerUser(user1.address);
      expect(await credits.balanceOf(user1.address)).to.equal(100n);
    });

    it("reverts for zero address", async () => {
      await expect(credits.registerUser(ethers.ZeroAddress))
        .to.be.revertedWithCustomError(credits, "ZeroAddress");
    });
  });

  describe("spendForAgentUse", () => {
    it("deducts 5 credits", async () => {
      await credits.registerUser(user1.address);
      await credits.spendForAgentUse(user1.address);
      expect(await credits.balanceOf(user1.address)).to.equal(95n);
    });

    it("reverts when balance is zero", async () => {
      // spend all credits (100 / 5 = 20 uses)
      await credits.registerUser(user2.address);
      for (let i = 0; i < 20; i++) await credits.spendForAgentUse(user2.address);
      await expect(credits.spendForAgentUse(user2.address))
        .to.be.revertedWithCustomError(credits, "InsufficientCredits");
    });
  });

  describe("spendForAgentCreate", () => {
    it("deducts 10 credits", async () => {
      await credits.registerUser(user1.address);
      await credits.spendForAgentCreate(user1.address);
      expect(await credits.balanceOf(user1.address)).to.equal(90n);
    });
  });

  describe("minter access", () => {
    it("allows adding a minter", async () => {
      await credits.addMinter(minter.address);
      expect(await credits.isMinter(minter.address)).to.be.true;
    });

    it("minter can registerUser", async () => {
      await credits.addMinter(minter.address);
      await credits.connect(minter).registerUser(user1.address);
      expect(await credits.balanceOf(user1.address)).to.equal(100n);
    });

    it("non-minter cannot registerUser", async () => {
      await expect(credits.connect(user1).registerUser(user2.address))
        .to.be.revertedWithCustomError(credits, "NotMinter");
    });

    it("allows removing a minter", async () => {
      await credits.addMinter(minter.address);
      await credits.removeMinter(minter.address);
      expect(await credits.isMinter(minter.address)).to.be.false;
    });
  });

  describe("getStats", () => {
    it("returns correct balance, totalEarned, totalSpent", async () => {
      await credits.registerUser(user1.address);
      await credits.spendForAgentUse(user1.address);   // -5
      await credits.spendForAgentCreate(user1.address); // -10
      const [balance, earned, spent] = await credits.getStats(user1.address);
      expect(balance).to.equal(85n);
      expect(earned).to.equal(100n);
      expect(spent).to.equal(15n);
    });
  });

  describe("grantCredits", () => {
    it("owner can grant extra credits", async () => {
      await credits.registerUser(user1.address);
      await credits.grantCredits(user1.address, 50, "Bonus");
      expect(await credits.balanceOf(user1.address)).to.equal(150n);
    });

    it("caps at MAX_CREDITS (10000)", async () => {
      await credits.grantCredits(user1.address, 10000, "Max grant");
      await credits.grantCredits(user1.address, 999, "Should be capped");
      expect(await credits.balanceOf(user1.address)).to.equal(10000n);
    });
  });
});
