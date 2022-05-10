import { BigNumberish } from "@ethersproject/bignumber";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";
import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";

import type { Lidogogo } from "../../src/types/contracts/Lidogogo";
import type { TestToken } from "../../src/types/contracts/TestToken";
import { Signers } from "../types";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.signer1 = signers[1];
    this.signers.signer2 = signers[2];
    this.signers.signer3 = signers[3];
    this.signers.signer4 = signers[4];
  });

  describe("Lidogogo", function () {
    beforeEach(async function () {
      const tknArtifact: Artifact = await artifacts.readArtifact("TestToken");
      this.tkn = <TestToken>(
        await waffle.deployContract(this.signers.admin, tknArtifact, [
          [
            this.signers.admin.address,
            this.signers.signer1.address,
            this.signers.signer2.address,
            this.signers.signer3.address,
            this.signers.signer4.address,
          ],
        ])
      );

      const lidogogoArtifact: Artifact = await artifacts.readArtifact("Lidogogo");
      this.lido = <Lidogogo>(
        await waffle.deployContract(this.signers.admin, lidogogoArtifact, [
          this.tkn.address,
          0x794a61358d6845594f94dc1db02a252b5b4814ad,
        ])
      ); //Aave V3 mainnet address
    });

    // Convert to smallest unit
    function su(amount: string): BigNumberish {
      return ethers.utils.parseEther(amount);
    }

    it("should mint 1000 tokens to each account", async function () {
      // Can use ethers utils for unit convertion as number of decimals is th same as ETH
      expect(await this.tkn.balanceOf(this.signers.admin.address)).to.equal(su("1000"));
      expect(await this.tkn.balanceOf(this.signers.signer1.address)).to.equal(su("1000"));
      expect(await this.tkn.balanceOf(this.signers.signer2.address)).to.equal(su("1000"));
      expect(await this.tkn.balanceOf(this.signers.signer3.address)).to.equal(su("1000"));
      expect(await this.tkn.balanceOf(this.signers.signer4.address)).to.equal(su("1000"));
    });

    it("should create project", async function () {
      let goal: BigNumberish = su("2500");
      await this.cf.connect(this.signers.admin).createProject(goal, 30);
      let project = await this.cf.projects(0);
      expect(project.creator).to.equal(this.signers.admin.address);
      expect(project.goal).to.equal(goal);
      expect(project.currentAmount).to.equal(0);
    });

    it("should fund project", async function () {
      // Create project
      let goal: BigNumberish = su("2500");
      await this.cf.connect(this.signers.admin).createProject(goal, 30);
      // Fund project
      let amount: BigNumberish = su("500");
      await this.tkn.connect(this.signers.signer1).approve(this.cf.address, amount);
      await this.cf.connect(this.signers.signer1).fundProject(0, amount);
      let project = await this.cf.projects(0);
      expect(await this.tkn.balanceOf(this.signers.signer1.address)).to.equal(amount);
      expect(await this.tkn.balanceOf(this.cf.address)).to.equal(amount);
      expect(project.currentAmount).to.equal(amount);
      expect(project.funders).to.equal(1);
    });

    it("should claim funds after successful funding", async function () {
      // Create project
      let goal: BigNumberish = su("500");
      await this.cf.connect(this.signers.admin).createProject(goal, 10);
      let blockNum: number = await ethers.provider.getBlockNumber();
      let block = await ethers.provider.getBlock(blockNum);
      let creationTime = block.timestamp;
      // Fund project
      let amount: BigNumberish = su("600");
      await this.tkn.connect(this.signers.signer1).approve(this.cf.address, amount);
      await this.cf.connect(this.signers.signer1).fundProject(0, amount);
      // Fast forward time to end funding
      let timestamp: number = creationTime + 11 * 24 * 3600; // 11 days
      await ethers.provider.send("evm_mine", [timestamp]);
      await this.cf.connect(this.signers.admin).claimFunds(0);
      let project = await this.cf.projects(0);
      expect(project.claimed).to.equal(amount);
      expect(project.currentAmount).to.equal(0);
    });

    it("should claim refunds if funding failed", async function () {
      // Create project
      let goal: BigNumberish = su("500");
      await this.cf.connect(this.signers.admin).createProject(goal, 10);
      let blockNum: number = await ethers.provider.getBlockNumber();
      let block = await ethers.provider.getBlock(blockNum);
      let creationTime = block.timestamp;
      // Fund project
      let amount: BigNumberish = su("400");
      await this.tkn.connect(this.signers.signer1).approve(this.cf.address, amount);
      await this.cf.connect(this.signers.signer1).fundProject(0, amount);
      // Fast forward time to end funding
      let timestamp: number = creationTime + 11 * 24 * 3600; // 11 days
      await ethers.provider.send("evm_mine", [timestamp]);
      // Claim refund
      await this.cf.connect(this.signers.signer1).claimRefund(0);
      let project = await this.cf.projects(0);
      expect(project.currentAmount).to.equal(0);
    });

    it("should allow reduction of funding", async function () {
      // Create project
      let goal: BigNumberish = su("500");
      await this.cf.connect(this.signers.admin).createProject(goal, 10);
      // Fund project
      let amount: BigNumberish = su("400");
      await this.tkn.connect(this.signers.signer1).approve(this.cf.address, amount);
      await this.cf.connect(this.signers.signer1).fundProject(0, amount);
      // Reduce Funding
      let reduceAmount1: BigNumberish = su("100");
      await this.cf.connect(this.signers.signer1).reduceFunding(0, reduceAmount1);
      let project = await this.cf.projects(0);
      expect(project.currentAmount).to.equal(su("300"));
      await expect(this.cf.connect(this.signers.signer1).reduceFunding(0, amount)).to.be.reverted;
    });
  });
});
