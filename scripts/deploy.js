const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  // 1. Deploy MockUSDC
  const MockUSDC = await hre.ethers.getContractFactory("MockUSDC");
  const mockUSDC = await MockUSDC.deploy();
  await mockUSDC.waitForDeployment();
  const usdcAddress = await mockUSDC.getAddress();
  console.log("MockUSDC deployed at:", usdcAddress);

  // 2. Deploy MockOracle
  const MockOracle = await hre.ethers.getContractFactory("MockOracle");
  const mockOracle = await MockOracle.deploy();
  await mockOracle.waitForDeployment();
  const oracleAddress = await mockOracle.getAddress();
  console.log("MockOracle deployed at:", oracleAddress);

  // 3. Deploy Factory
  const Factory = await hre.ethers.getContractFactory("StrategyFactory");
  const factory = await Factory.deploy(oracleAddress);
  await factory.waitForDeployment();
  const factoryAddress = await factory.getAddress();
  console.log("Factory deployed at:", factoryAddress);

  // Guardar endereços em deployment.json
  const deployment = {
    localhost: {
      USDC: usdcAddress,
      Factory: factoryAddress,
      Oracle: oracleAddress
    }
  };

  const deploymentPath = path.join(__dirname, '../deployment.json');
  fs.writeFileSync(deploymentPath, JSON.stringify(deployment, null, 2));
  console.log("Deployment addresses saved to deployment.json");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});