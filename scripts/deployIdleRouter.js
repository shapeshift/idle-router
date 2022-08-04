require("dotenv").config();
const {ethers, upgrades } = require("hardhat");


async function main () {
  const IdleRouter = await ethers.getContractFactory("IdleRouter");
  const idleRouter = await upgrades.deployProxy(IdleRouter, [
    "0x84FDeE80F18957A041354E99C7eB407467D94d8E" // idle registry address
  ]);
  await idleRouter.deployed();
  console.log("IdleRouter deployed to ", idleRouter.address);
};


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });