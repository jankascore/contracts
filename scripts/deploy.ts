import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  const JankaProtocol = await ethers.getContractFactory("JankaProtocol");
  const janka = await JankaProtocol.deploy();
  const tx = await janka.deployed();

  console.log(`Deployer (owner): ${deployer.address}`);
  console.log(`Contract address: ${janka.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
