import { BigNumberish } from "@ethersproject/bignumber";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";
import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";

import type { Crowdfund } from "../../src/types/contracts/Crowdfund";
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

  describe("Crowdfund", function () {
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

      const cfArtifact: Artifact = await artifacts.readArtifact("Crowdfund");
      this.cf = <Crowdfund>await waffle.deployContract(this.signers.admin, cfArtifact, [this.tkn.address]);
    });

    it("should mint 1000 tokens to each account", async function () {
      // Can use ethers utils for unit convertion as number of decimals is th same as ETH
      expect(await this.tkn.balanceOf(this.signers.admin.address)).to.equal(ethers.utils.parseEther("1000"));
      expect(await this.tkn.balanceOf(this.signers.signer1.address)).to.equal(ethers.utils.parseEther("1000"));
      expect(await this.tkn.balanceOf(this.signers.signer2.address)).to.equal(ethers.utils.parseEther("1000"));
      expect(await this.tkn.balanceOf(this.signers.signer3.address)).to.equal(ethers.utils.parseEther("1000"));
      expect(await this.tkn.balanceOf(this.signers.signer4.address)).to.equal(ethers.utils.parseEther("1000"));
    });

    it("should create project", async function () {
      let goal: BigNumberish = ethers.utils.parseEther("2500");
      await this.cf.connect(this.signers.admin).createProject(goal, 30);
      let project = await this.cf.projects(0);
      expect(project.creator).to.equal(this.signers.admin.address);
      expect(project.goal).to.equal(goal);
      expect(project.currentAmount).to.equal(0);
    });

    it("should fund project", async function () {
      // Create project
      let goal: BigNumberish = ethers.utils.parseEther("2500");
      await this.cf.connect(this.signers.admin).createProject(goal, 30);

      // Fund project
      let amount: BigNumberish = ethers.utils.parseEther("500");
      await this.tkn.connect(this.signers.signer1).approve(this.cf.address, amount);
      await this.cf.connect(this.signers.signer1).fundProject(0, amount);
      let project = await this.cf.projects(0);
      expect(await this.tkn.balanceOf(this.signers.signer1.address)).to.equal(amount);
      expect(await this.tkn.balanceOf(this.cf.address)).to.equal(amount);
      expect(project.currentAmount).to.equal(amount);
      expect(project.funders).to.equal(1);
    });
  });
});
