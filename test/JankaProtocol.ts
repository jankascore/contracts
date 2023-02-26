import { expect } from "chai";
import { ethers } from "hardhat";
// import { parseEther, parseUnits } from "ethers/lib/utils";
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";

describe("JankaProtocol", () => {
  async function setupFixture() {
    const [deployer, otherAccount] = await ethers.getSigners();

    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    const ONE_GWEI = 1_000_000_000;

    const lockedAmount = ONE_GWEI;
    const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS;

    const JankaProtocol = await ethers.getContractFactory("JankaProtocol");
    const janka = await JankaProtocol.deploy(unlockTime, {
      value: lockedAmount,
    });

    return { janka, unlockTime, lockedAmount, deployer, otherAccount };
  }

  describe("Deployment", () => {
    it("Should set the right unlockTime", async () => {
      const { janka, unlockTime } = await loadFixture(setupFixture);

      expect(await janka.unlockTime()).to.equal(unlockTime);
    });

    it("Should set the right owner", async () => {
      const { janka, deployer } = await loadFixture(setupFixture);

      expect(await janka.owner()).to.equal(deployer.address);
    });

    it("Should receive and store the funds to janka", async () => {
      const { janka, lockedAmount } = await loadFixture(setupFixture);

      expect(await ethers.provider.getBalance(janka.address)).to.equal(
        lockedAmount
      );
    });

    it("Should fail if the unlockTime is not in the future", async () => {
      // We don't use the fixture here because we want a different deployment
      const latestTime = await time.latest();
      const JankaProtocol = await ethers.getContractFactory("JankaProtocol");
      await expect(
        JankaProtocol.deploy(latestTime, { value: 1 })
      ).to.be.revertedWith("Unlock time should be in the future");
    });
  });

  describe("Withdrawals", () => {
    describe("Validations", () => {
      it("Should revert with the right error if called too soon", async () => {
        const { janka } = await loadFixture(setupFixture);

        await expect(janka.withdraw()).to.be.revertedWith(
          "You can't withdraw yet"
        );
      });

      it("Should revert with the right error if called from another account", async () => {
        const { janka, unlockTime, otherAccount } = await loadFixture(
          setupFixture
        );

        // We can increase the time in Hardhat Network
        await time.increaseTo(unlockTime);

        // We use janka.connect() to send a transaction from another account
        await expect(janka.connect(otherAccount).withdraw()).to.be.revertedWith(
          "You aren't the owner"
        );
      });

      it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async () => {
        const { janka, unlockTime } = await loadFixture(setupFixture);

        // Transactions are sent using the first signer by default
        await time.increaseTo(unlockTime);

        await expect(janka.withdraw()).not.to.be.reverted;
      });
    });

    describe("Events", () => {
      it("Should emit an event on withdrawals", async () => {
        const { janka, unlockTime, lockedAmount } = await loadFixture(
          setupFixture
        );

        await time.increaseTo(unlockTime);

        await expect(janka.withdraw())
          .to.emit(janka, "Withdrawal")
          .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg
      });
    });

    describe("Transfers", () => {
      it("Should transfer the funds to the owner", async () => {
        const { janka, unlockTime, lockedAmount, deployer } = await loadFixture(
          setupFixture
        );

        await time.increaseTo(unlockTime);

        await expect(janka.withdraw()).to.changeEtherBalances(
          [deployer, janka],
          [lockedAmount, -lockedAmount]
        );
      });
    });
  });
});
