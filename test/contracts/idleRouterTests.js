const { expect } = require("chai");
const { ethers, network, upgrades } = require("hardhat");
const ERC20 = require("@openzeppelin/contracts/build/contracts/ERC20.json");

const DAI_CDO_ADDRESS = "0xd0DbcD556cA22d3f3c142e9a3220053FD7a247BC";
const DAI_CDO_AA_TRANCHE = "0xe9ada97bdb86d827ecbaacca63ebcd8201d8b12e";
const DAI_CDO_BB_TRANCHE = "0x730348a54ba58f64295154f0662a08cbde1225c2";
const DAI_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const DAI_WHALE = "0xe78388b4ce79068e89bf8aa7f218ef6b9ab0e9d0";

describe("IdleRouter", () => {
  let idleRouter;
  let idleRegistry;
  let accounts;
  let daiWhaleSigner;
  let daiToken;
  let daiAAToken;
  let daiBBToken;

  beforeEach(async () => {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.MAINNET_URL,
            blockNumber: Number(process.env.FORK_BLOCK_NUMBER),
          },
        },
      ],
    });
    accounts = await ethers.getSigners();

    const IdleRegistry = await ethers.getContractFactory("IdleRegistry");
    idleRegistry = await IdleRegistry.deploy();
    await idleRegistry.deployed();

    // add an example CDO to interact with
    await idleRegistry.setIdleCdo(DAI_CDO_ADDRESS);

    // add dai to needed accounts
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [DAI_WHALE],
    });
    daiWhaleSigner = await ethers.getSigner(DAI_WHALE);

    daiToken = new ethers.Contract(DAI_ADDRESS, ERC20.abi, daiWhaleSigner);
    daiAAToken = new ethers.Contract(
      DAI_CDO_AA_TRANCHE,
      ERC20.abi,
      accounts[0]
    );
    daiBBToken = new ethers.Contract(
      DAI_CDO_BB_TRANCHE,
      ERC20.abi,
      accounts[0]
    );

    await accounts[0].sendTransaction({
      to: DAI_WHALE,
      value: ethers.utils.parseUnits("10", 18),
    });
    const initialDaiBalance = ethers.utils.parseUnits("100000", 18);
    await daiToken.transfer(accounts[1].address, initialDaiBalance);
    await daiToken.transfer(accounts[2].address, initialDaiBalance);

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

  describe("depositAA", () => {
    it("succeeds for a CDO in the registry", async () => {
      const staker1 = accounts[1];
      const amountToTransfer = ethers.utils.parseUnits("50", 18);
      const initialDaiBalanceOfStaker1 = await daiToken.balanceOf(
        staker1.address
      );
      await daiToken
        .connect(staker1)
        .approve(idleRouter.address, amountToTransfer.mul(2));

      expect(await daiToken.balanceOf(idleRouter.address)).to.equal(0);
      expect(await daiAAToken.balanceOf(staker1.address)).to.equal(0);
      await idleRouter
        .connect(staker1)
        .depositAA(DAI_CDO_ADDRESS, amountToTransfer);
      expect(await daiToken.balanceOf(idleRouter.address)).to.equal(0);

      const expectedBalanceAfterDeposit =
        initialDaiBalanceOfStaker1.sub(amountToTransfer);
      expect(await daiToken.balanceOf(staker1.address)).to.equal(
        expectedBalanceAfterDeposit
      );
      expect(await daiAAToken.balanceOf(staker1.address)).to.not.equal(0);

      await expect(
        await idleRouter
          .connect(staker1)
          .depositAA(DAI_CDO_ADDRESS, amountToTransfer)
      ).to.emit(idleRouter, "TokensDeposited");
    });

    it("reverts for a CDO not in the registry", async () => {
      const staker1 = accounts[1];
      const amountToTransfer = ethers.utils.parseUnits("50", 18);
      await expect(
        idleRouter
          .connect(staker1)
          .depositAA(daiAAToken.address, amountToTransfer)
      ).to.be.revertedWith("IdleRouter: INVALID_CDO");
    });

    it("reverts with an _amount of zero", async () => {
      const staker1 = accounts[1];
      const amountToTransfer = 0;

      await expect(
        idleRouter.connect(staker1).depositAA(DAI_CDO_ADDRESS, amountToTransfer)
      ).to.be.revertedWith("IdleRouter: INVALID_AMOUNT");
    });

    it("sends the correct amount to the user even if the contract has a balance of that token", async () => {
      const staker1 = accounts[1];
      const maliciousSender = accounts[2];

      const amountToTransferBefore = ethers.utils.parseUnits("5", 18);
      const amountToTransfer = ethers.utils.parseUnits("50", 18);

      const daiMalSender = await daiToken.connect(maliciousSender);

      await daiMalSender.transfer(idleRouter.address, amountToTransferBefore);

      const initialDaiBalanceOfStaker1 = await daiToken.balanceOf(
        staker1.address
      );

      await daiToken
        .connect(staker1)
        .approve(idleRouter.address, amountToTransfer.mul(2));

      expect(await daiToken.balanceOf(idleRouter.address)).to.equal(
        amountToTransferBefore
      );
      expect(await daiAAToken.balanceOf(staker1.address)).to.equal(0);

      await idleRouter
        .connect(staker1)
        .depositAA(DAI_CDO_ADDRESS, amountToTransfer);
      expect(await daiToken.balanceOf(idleRouter.address)).to.equal(
        amountToTransferBefore
      );

      const expectedBalanceAfterDeposit =
        initialDaiBalanceOfStaker1.sub(amountToTransfer);

      expect(await daiToken.balanceOf(staker1.address)).to.equal(
        expectedBalanceAfterDeposit
      );
      expect(await daiAAToken.balanceOf(staker1.address)).to.not.equal(0);

      await expect(
        await idleRouter
          .connect(staker1)
          .depositAA(DAI_CDO_ADDRESS, amountToTransfer)
      ).to.emit(idleRouter, "TokensDeposited");
    });
  });

  describe("depositBB", () => {
    it("succeeds for a CDO in the registry", async () => {
      const staker1 = accounts[1];
      const amountToTransfer = ethers.utils.parseUnits("50", 18);
      const initialDaiBalanceOfStaker1 = await daiToken.balanceOf(
        staker1.address
      );
      await daiToken
        .connect(staker1)
        .approve(idleRouter.address, amountToTransfer.mul(2));

      expect(await daiToken.balanceOf(idleRouter.address)).to.equal(0);
      expect(await daiBBToken.balanceOf(staker1.address)).to.equal(0);
      await idleRouter
        .connect(staker1)
        .depositBB(DAI_CDO_ADDRESS, amountToTransfer);
      expect(await daiToken.balanceOf(idleRouter.address)).to.equal(0);

      const expectedBalanceAfterDeposit =
        initialDaiBalanceOfStaker1.sub(amountToTransfer);
      expect(await daiToken.balanceOf(staker1.address)).to.equal(
        expectedBalanceAfterDeposit
      );
      expect(await daiBBToken.balanceOf(staker1.address)).to.not.equal(0);

      await expect(
        await idleRouter
          .connect(staker1)
          .depositBB(DAI_CDO_ADDRESS, amountToTransfer)
      ).to.emit(idleRouter, "TokensDeposited");
    });

    it("reverts for a CDO not in the registry", async () => {
      const staker1 = accounts[1];
      const amountToTransfer = ethers.utils.parseUnits("50", 18);
      await expect(
        idleRouter
          .connect(staker1)
          .depositBB(daiAAToken.address, amountToTransfer)
      ).to.be.revertedWith("IdleRouter: INVALID_CDO");
    });
  });

  describe("withdrawAA", () => {
    it("succeeds for a CDO in the registry", async () => {
      const staker1 = accounts[1];
      const amountToTransfer = ethers.utils.parseUnits("50", 18);
      const initialDaiBalanceOfStaker1 = await daiToken.balanceOf(
        staker1.address
      );
      await daiToken
        .connect(staker1)
        .approve(idleRouter.address, amountToTransfer.mul(2));
      expect(await daiAAToken.balanceOf(staker1.address)).to.equal(0);
      await idleRouter
        .connect(staker1)
        .depositAA(DAI_CDO_ADDRESS, amountToTransfer);

      const trancheTokenBalance = await daiAAToken.balanceOf(staker1.address);
      await daiAAToken
        .connect(staker1)
        .approve(idleRouter.address, trancheTokenBalance);
      await idleRouter
        .connect(staker1)
        .withdrawAA(daiAAToken.address, trancheTokenBalance);

      // should get back more token then deposited.
      expect(
        (await daiToken.balanceOf(staker1.address)).gt(
          initialDaiBalanceOfStaker1
        )
      );
      expect(await daiAAToken.balanceOf(staker1.address)).to.equal(0);
    });

    it("reverts for a token not recognized", async () => {
      const staker1 = accounts[1];
      const amountToTransfer = ethers.utils.parseUnits("50", 18);
      await daiToken
        .connect(staker1)
        .approve(idleRouter.address, amountToTransfer.mul(2));
      expect(await daiAAToken.balanceOf(staker1.address)).to.equal(0);
      await idleRouter
        .connect(staker1)
        .depositAA(DAI_CDO_ADDRESS, amountToTransfer);

      const trancheTokenBalance = await daiAAToken.balanceOf(staker1.address);
      await daiAAToken
        .connect(staker1)
        .approve(idleRouter.address, trancheTokenBalance);
      await expect(
        idleRouter
          .connect(staker1)
          .withdrawAA(daiToken.address, trancheTokenBalance)
      ).to.be.reverted;
    });

    it("emits TokensWithdrew event", async () => {
      const staker1 = accounts[1];
      const amountToTransfer = ethers.utils.parseUnits("50", 18);

      await daiToken
        .connect(staker1)
        .approve(idleRouter.address, amountToTransfer.mul(2));
      expect(await daiAAToken.balanceOf(staker1.address)).to.equal(0);
      await idleRouter
        .connect(staker1)
        .depositAA(DAI_CDO_ADDRESS, amountToTransfer);

      const trancheTokenBalance = await daiAAToken.balanceOf(staker1.address);
      await daiAAToken
        .connect(staker1)
        .approve(idleRouter.address, trancheTokenBalance);

      await expect(
        await idleRouter
          .connect(staker1)
          .withdrawAA(daiAAToken.address, trancheTokenBalance)
      ).to.emit(idleRouter, "TokensWithdrew");
    });

    it("sends the correct amount to the user even if the contract has a balance of that token", async () => {
      const staker1 = accounts[1];
      const maliciousSender = accounts[2];

      const amountToTransferBefore = ethers.utils.parseUnits("5", 18);
      const amountToTransfer = ethers.utils.parseUnits("50", 18);

      const daiMalSender = await daiToken.connect(maliciousSender);

      await daiMalSender.transfer(idleRouter.address, amountToTransferBefore);

      const initialDaiBalanceOfStaker1 = await daiToken.balanceOf(
        staker1.address
      );

      await daiToken
        .connect(staker1)
        .approve(idleRouter.address, amountToTransfer.mul(2));
      expect(await daiAAToken.balanceOf(staker1.address)).to.equal(0);
      await idleRouter
        .connect(staker1)
        .depositAA(DAI_CDO_ADDRESS, amountToTransfer);

      const trancheTokenBalance = await daiAAToken.balanceOf(staker1.address);
      await daiAAToken
        .connect(staker1)
        .approve(idleRouter.address, trancheTokenBalance);
      await idleRouter
        .connect(staker1)
        .withdrawAA(daiAAToken.address, trancheTokenBalance);

      // should get back more token then deposited.
      expect(
        (await daiToken.balanceOf(staker1.address)).gt(
          initialDaiBalanceOfStaker1
        )
      );
      expect(await daiAAToken.balanceOf(staker1.address)).to.equal(0);
    });
  });

  describe("withdrawBB", () => {
    it("succeeds for a CDO in the registry", async () => {
      const staker1 = accounts[1];
      const amountToTransfer = ethers.utils.parseUnits("50", 18);
      const initialDaiBalanceOfStaker1 = await daiToken.balanceOf(
        staker1.address
      );
      await daiToken
        .connect(staker1)
        .approve(idleRouter.address, amountToTransfer.mul(2));
      expect(await daiBBToken.balanceOf(staker1.address)).to.equal(0);
      await idleRouter
        .connect(staker1)
        .depositBB(DAI_CDO_ADDRESS, amountToTransfer);

      const trancheTokenBalance = await daiBBToken.balanceOf(staker1.address);
      await daiBBToken
        .connect(staker1)
        .approve(idleRouter.address, trancheTokenBalance);
      await idleRouter
        .connect(staker1)
        .withdrawBB(daiBBToken.address, trancheTokenBalance);

      // should get back more token then deposited.
      expect(
        (await daiToken.balanceOf(staker1.address)).gt(
          initialDaiBalanceOfStaker1
        )
      );
      expect(await daiBBToken.balanceOf(staker1.address)).to.equal(0);
    });

    it("reverts for a token not recognized", async () => {
      const staker1 = accounts[1];
      const amountToTransfer = ethers.utils.parseUnits("50", 18);
      await daiToken
        .connect(staker1)
        .approve(idleRouter.address, amountToTransfer.mul(2));
      expect(await daiBBToken.balanceOf(staker1.address)).to.equal(0);
      await idleRouter
        .connect(staker1)
        .depositBB(DAI_CDO_ADDRESS, amountToTransfer);

      const trancheTokenBalance = await daiBBToken.balanceOf(staker1.address);
      await daiBBToken
        .connect(staker1)
        .approve(idleRouter.address, trancheTokenBalance);
      await expect(
        idleRouter
          .connect(staker1)
          .withdrawBB(daiToken.address, trancheTokenBalance)
      ).to.be.reverted;
    });
  });

  describe("can be upgraded", () => {
    it("upgrades successfully", async () => {
      const IdleRouterV2 = await ethers.getContractFactory("IdleRouterV2");
      const idleRouterV2 = await upgrades.upgradeProxy(
        idleRouter.address,
        IdleRouterV2
      );

      await idleRouterV2.deployed();
      await idleRouterV2.setUpgraded(true);

      expect(await idleRouter.isUpgraded).to.equal(undefined);
      expect(await idleRouterV2.isUpgraded()).to.equal(true);
    });

    it("deposit succeeds for a CDO in the registry after an upgrade", async () => {
      const IdleRouterV2 = await ethers.getContractFactory("IdleRouterV2");
      const idleRouterV2 = await upgrades.upgradeProxy(
        idleRouter.address,
        IdleRouterV2
      );

      await idleRouterV2.deployed();

      const staker1 = accounts[1];
      const amountToTransfer = ethers.utils.parseUnits("50", 18);
      const initialDaiBalanceOfStaker1 = await daiToken.balanceOf(
        staker1.address
      );
      await daiToken
        .connect(staker1)
        .approve(idleRouter.address, amountToTransfer.mul(2));

      expect(await daiToken.balanceOf(idleRouterV2.address)).to.equal(0);
      expect(await daiAAToken.balanceOf(staker1.address)).to.equal(0);
      await idleRouterV2
        .connect(staker1)
        .depositAA(DAI_CDO_ADDRESS, amountToTransfer);
      expect(await daiToken.balanceOf(idleRouterV2.address)).to.equal(0);

      const expectedBalanceAfterDeposit =
        initialDaiBalanceOfStaker1.sub(amountToTransfer);
      expect(await daiToken.balanceOf(staker1.address)).to.equal(
        expectedBalanceAfterDeposit
      );
      expect(await daiAAToken.balanceOf(staker1.address)).to.not.equal(0);

      await expect(
        await idleRouterV2
          .connect(staker1)
          .depositAA(DAI_CDO_ADDRESS, amountToTransfer)
      ).to.emit(idleRouterV2, "TokensDeposited");
    });

    it("deposit reverts for a CDO not in the registry after an upgrade", async () => {
      const IdleRouterV2 = await ethers.getContractFactory("IdleRouterV2");
      const idleRouterV2 = await upgrades.upgradeProxy(
        idleRouter.address,
        IdleRouterV2
      );

      await idleRouterV2.deployed();

      const staker1 = accounts[1];
      const amountToTransfer = ethers.utils.parseUnits("50", 18);
      await expect(
        idleRouterV2
          .connect(staker1)
          .depositAA(daiAAToken.address, amountToTransfer)
      ).to.be.revertedWith("IdleRouter: INVALID_CDO");
    });
  });
});
