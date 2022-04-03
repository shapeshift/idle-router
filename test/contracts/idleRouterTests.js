const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("IdleRouter", () => {
  let idleRouter;
  let idleRegistry;
  let accounts;

  beforeEach(async () => {
    accounts = await ethers.getSigners();

    const IdleRegistry = await ethers.getContractFactory("IdleRegistry");
    idleRegistry = await IdleRegistry.deploy();
    await idleRegistry.deployed();

    const IdleRouter = await ethers.getContractFactory("IdleRouter");
    idleRouter = await upgrades.deployProxy(IdleRouter, [idleRegistry.address]);
    await idleRouter.deployed();
  });

  describe("initialize", () => {
    it("sets variables correctly", async () => {
      expect(await idleRouter.owner()).to.equal(accounts[0].address);
      expect(await idleRouter.idleRegistry()).to.equal(idleRegistry.address);
    });
  });

  describe("setIdleRegistry", () => {
    it("sets the registry and emits events when called from owner", async () => {
      await expect(await idleRouter.setIdleRegistry(accounts[1].address))
        .to.emit(idleRouter, "IdleRegistryUpdated")
        .withArgs(accounts[1].address);
      expect(await idleRouter.idleRegistry()).to.equal(accounts[1].address);
    });

    it("reverts when called from non-owner", async () => {
      await expect(
        idleRouter.connect(accounts[1]).setIdleRegistry(accounts[1].address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("reverts when called with same address or zero address", async () => {
      await expect(
        idleRouter.setIdleRegistry(await idleRouter.idleRegistry())
      ).to.be.revertedWith("IdleRouter: INVALID_ADDRESS");
      await expect(
        idleRouter.setIdleRegistry(ethers.constants.AddressZero)
      ).to.be.revertedWith("IdleRouter: INVALID_ADDRESS");
    });
  });
});
