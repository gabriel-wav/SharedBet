const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying with:", deployer.address);

  const ORACLE_ADDRESS = "0xSEU_ORACLE_AQUI";

  const Factory = await hre.ethers.getContractFactory("StrategyFactory");
  const factory = await Factory.deploy(ORACLE_ADDRESS);

  await factory.waitForDeployment();

  console.log("Factory deployed at:", await factory.getAddress());
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
