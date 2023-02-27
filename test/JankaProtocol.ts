import { expect } from "chai";
import { ethers } from "hardhat";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

const MOCK_CID = "bafkreidgvpkjawlxz6sffxzwgooowe5yt7i6wsyg236mfoks77nywkptdq";

describe("JankaProtocol", () => {
  async function setupFixture() {
    const [deployer, alice] = await ethers.getSigners();

    const JankaProtocol = await ethers.getContractFactory("JankaProtocol");
    const janka = await JankaProtocol.deploy();
    await janka.deployed();

    await janka.connect(deployer).allowAlgorithmCID(MOCK_CID);

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

      await expect(janka.connect(alice).attest(bogusScore, MOCK_CID))
        .to.be.revertedWithCustomError(janka, "InvalidScore")
        .withArgs(0, 100, bogusScore);
    });

    it("should reject an algorithm that hasn't been allowlisted", async () => {
      const { janka, alice } = await loadFixture(setupFixture);
      const bogusCID = "QmbWqxBEKC3P8tqsKc98xmWNzrzDtRLMiMPL8wBuTGsMnR";

      await expect(
        janka.connect(alice).attest(50, bogusCID)
      ).to.be.revertedWithCustomError(janka, "InvalidAlgorithm");
    });

    it("should reject an additional attestation if one is in-flight from the same EOA", async () => {
      const { janka, alice } = await loadFixture(setupFixture);
      const requiredStake = await janka.REQUIRED_ATTESTATION_STAKE();

      await janka.connect(alice).attest(50, MOCK_CID, { value: requiredStake });
      await expect(
        janka.connect(alice).attest(50, MOCK_CID, { value: requiredStake })
      ).to.be.revertedWithCustomError(janka, "AttestationAlreadyExists");
    });

    it("should enforce that the *exact* required stake is provided", async () => {
      const { janka, alice } = await loadFixture(setupFixture);
      const requiredStake = await janka.REQUIRED_ATTESTATION_STAKE();

      // Try first without providing any ether.
      await expect(janka.connect(alice).attest(0, MOCK_CID))
        .to.be.revertedWithCustomError(janka, "IncorrectStakeAmount")
        .withArgs(requiredStake, 0);

      // Next, try with too much ether.
      await expect(
        janka
          .connect(alice)
          .attest(0, MOCK_CID, { value: requiredStake.add(1) })
      )
        .to.be.revertedWithCustomError(janka, "IncorrectStakeAmount")
        .withArgs(requiredStake, requiredStake.add(1));

      // Finally, try with the exact amount.
      await expect(
        janka.connect(alice).attest(0, MOCK_CID, { value: requiredStake })
      ).to.not.be.reverted;
    });

    it("should emit a ScoreAttested event", async () => {
      const { janka, alice } = await loadFixture(setupFixture);
      const score = 50;
      const requiredStake = await janka.REQUIRED_ATTESTATION_STAKE();

      await expect(
        janka.connect(alice).attest(score, MOCK_CID, { value: requiredStake })
      )
        .to.emit(janka, "ScoreAttested")
        .withArgs(alice.address, score, MOCK_CID, anyValue);
    });
  });

  describe("when calling allowAlgorithmCID()", () => {
    it("should add the algorithm CID to the list of CIDs", async () => {
      const { janka, deployer } = await loadFixture(setupFixture);

      await janka.connect(deployer).allowAlgorithmCID(MOCK_CID);
      expect(await janka.supportedAlgorithms(MOCK_CID)).to.be.true;
    });

    it("should only allow the contract owner to call it", async () => {
      const { janka, alice } = await loadFixture(setupFixture);

      await expect(
        janka.connect(alice).allowAlgorithmCID(MOCK_CID)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});
