import { expect } from "chai";
import { ethers } from "hardhat";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("JankaProtocol", () => {
  async function setupFixture() {
    const [deployer, alice] = await ethers.getSigners();

    const JankaProtocol = await ethers.getContractFactory("JankaProtocol");
    const janka = await JankaProtocol.deploy();

    return { janka, deployer, alice };
  }

  it("should successfully deploy", async () => {
    const { janka } = await loadFixture(setupFixture);
    expect(janka.address).to.be.properAddress;
  });

  it("should make the deployer the initial owner", async () => {
    const { janka, deployer } = await loadFixture(setupFixture);
    expect(await janka.owner()).to.equal(deployer.address);
  });

  describe("when an EOA submits an attestation of a score", () => {
    it("should reject an invalid score", async () => {
      const { janka, alice } = await loadFixture(setupFixture);
      const bogusScore = 101;

      await expect(janka.connect(alice).attest(bogusScore))
        .to.be.revertedWithCustomError(janka, "InvalidScore")
        .withArgs(0, 100, bogusScore);
    });

    it("should require the appropriate stake is provided", async () => {
      const { janka, alice } = await loadFixture(setupFixture);
      const requiredStake = await janka.REQUIRED_ATTESTATION_STAKE();

      // Try first without providing any ether.
      await expect(janka.connect(alice).attest(0))
        .to.be.revertedWithCustomError(janka, "InsufficientStake")
        .withArgs(requiredStake, 0);

      // Try again with a sufficient amount.
      await expect(janka.connect(alice).attest(0, { value: requiredStake })).to
        .not.be.reverted;
    });

    it("should emit a ScoreAttested event", async () => {
      const { janka, alice } = await loadFixture(setupFixture);
      const score = 50;
      const requiredStake = await janka.REQUIRED_ATTESTATION_STAKE();

      await expect(janka.connect(alice).attest(score, { value: requiredStake }))
        .to.emit(janka, "ScoreAttested")
        .withArgs(alice.address, score, anyValue);
    });
  });
});
