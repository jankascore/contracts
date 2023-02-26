import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("JankaProtocol", () => {
  async function setupFixture() {
    const [deployer] = await ethers.getSigners();

    const JankaProtocol = await ethers.getContractFactory("JankaProtocol");
    const janka = await JankaProtocol.deploy();

    return { janka, deployer };
  }

  it("should successfully deploy", async () => {
    const { janka } = await loadFixture(setupFixture);
    expect(janka.address).to.be.properAddress;
  });
});
