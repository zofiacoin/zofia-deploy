const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("🚀 Deploying ZOFIA with account:", deployer.address);
  const ZOFIA = await hre.ethers.getContractFactory("ZOFIA");
  const contract = await ZOFIA.deploy(deployer.address);
  await contract.waitForDeployment();
  console.log("✅ ZOFIA deployed to:", await contract.getAddress());
  console.log("🔗 https://etherscan.io/address/" + await contract.getAddress());
}

main().catch(console.error);
