import { BigNumberish } from "@ethersproject/bignumber";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";
import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";

import type { Lidogogo } from "../../src/types/contracts/Lidogogo";
//import type { TestToken } from "../../src/types/contracts/TestToken";
import { Signers } from "../types";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.bob = signers[1];
    this.signers.alice = signers[2];
    this.signers.sam = signers[3];
    this.signers.tom = signers[4];
  });

  describe("Lidogogo", function () {
    beforeEach(async function () {
      /*
      const tknArtifact: Artifact = await artifacts.readArtifact("TestToken");
      this.tkn = <TestToken>(
        await waffle.deployContract(this.signers.admin, tknArtifact, [
          [
            this.signers.admin.address,
            this.signers.bob.address,
            this.signers.alice.address,
            this.signers.sam.address,
            this.signers.tom.address,
          ],
        ])
      );
      */

      const lidogogoArtifact: Artifact = await artifacts.readArtifact("Lidogogo");
      this.lido = <Lidogogo>await waffle.deployContract(this.signers.admin, lidogogoArtifact);
      await this.lido.initialize(
        "0xB4378b192236D62920b9b75Fb42E723184cd357c", // LIND Token on Rinkeby
        "0x87530ED4bd0ee0e79661D65f8Dd37538F693afD5", // Aave V3 Pool Contract on Rinkeby
      );
    });

    // Convert to smallest unit
    function su(amount: string): BigNumberish {
      return ethers.utils.parseEther(amount);
    }

    xit("should mint 1000 tokens to each account", async function () {
      // Can use ethers utils for unit convertion as number of decimals is th same as ETH
      expect(await this.tkn.balanceOf(this.signers.admin.address)).to.equal(su("1000"));
      expect(await this.tkn.balanceOf(this.signers.bob.address)).to.equal(su("1000"));
      expect(await this.tkn.balanceOf(this.signers.alice.address)).to.equal(su("1000"));
      expect(await this.tkn.balanceOf(this.signers.sam.address)).to.equal(su("1000"));
      expect(await this.tkn.balanceOf(this.signers.tom.address)).to.equal(su("1000"));
    });

    it("should create project", async function () {
      const goal: BigNumberish = su("3500");
      await this.lido.connect(this.signers.admin).createProject(goal, 200);
      const project = await this.lido.projects(0);
      expect(project.creator).to.equal(this.signers.admin.address);
      expect(project.goal).to.equal(goal);
      expect(project.currentAmount).to.equal(0);
    });

    xit("should fund project", async function () {
      // Create project
      const goal: BigNumberish = su("2500");
      await this.lido.connect(this.signers.admin).createProject(goal, 30);
      // Fund project
      const amount: BigNumberish = su("500");
      await this.tkn.connect(this.signers.bob).approve(this.lido.address, amount);
      await this.lido.connect(this.signers.bob).fundProject(0, amount);
      const project = await this.lido.projects(0);
      expect(await this.lido.connect(this.signers.bob).getFundedAmount(0)).to.equal(amount);
      expect(await this.tkn.balanceOf(this.lido.address)).to.equal(amount);
      expect(project.currentAmount).to.equal(amount);
      expect(project.funders).to.equal(1);
    });

    /*
    it("should claim funds after successful funding", async function () {
      // Create project
      const goal: BigNumberish = su("500");
      await this.lido.connect(this.signers.admin).createProject(goal, 10);
      const blockNum: number = await ethers.provider.getBlockNumber();
      const block = await ethers.provider.getBlock(blockNum);
      const creationTime = block.timestamp;
      // Fund project
      const amount: BigNumberish = su("600");
      await this.tkn.connect(this.signers.bob).approve(this.lido.address, amount);
      await this.lido.connect(this.signers.bob).fundProject(0, amount);
      // Fast forward time to end funding
      const timestamp: number = creationTime + 11 * 24 * 3600; // 11 days
      await ethers.provider.send("evm_mine", [timestamp]);
      await this.lido.connect(this.signers.admin).claimFunds(0);
      const project = await this.lido.projects(0);
      expect(project.claimed).to.equal(amount);
      expect(project.currentAmount).to.equal(0);
    });
    */

    xit("should claim refunds if funding failed", async function () {
      // Create project
      const goal: BigNumberish = su("500");
      await this.lido.connect(this.signers.admin).createProject(goal, 10);
      const blockNum: number = await ethers.provider.getBlockNumber();
      const block = await ethers.provider.getBlock(blockNum);
      const creationTime = block.timestamp;
      // Fund project
      const amount: BigNumberish = su("400");
      await this.tkn.connect(this.signers.bob).approve(this.lido.address, amount);
      await this.lido.connect(this.signers.bob).fundProject(0, amount);
      // Fast forward time to end funding
      const timestamp: number = creationTime + 11 * 24 * 3600; // 11 days
      await ethers.provider.send("evm_mine", [timestamp]);
      // Claim refund
      await this.lido.connect(this.signers.bob).fundingRefund(0);
      const project = await this.lido.projects(0);
      expect(project.currentAmount).to.equal(0);
      expect(await this.lido.connect(this.signers.bob).getFundedAmount(0)).to.equal(0);
    });

    xit("should allow reduction of funding", async function () {
      // Create project
      const goal: BigNumberish = su("500");
      await this.lido.connect(this.signers.admin).createProject(goal, 10);
      // Fund project
      const amount: BigNumberish = su("400");
      await this.tkn.connect(this.signers.bob).approve(this.lido.address, amount);
      await this.lido.connect(this.signers.bob).fundProject(0, amount);
      // Reduce Funding
      const reduceAmount1: BigNumberish = su("100");
      await this.lido.connect(this.signers.bob).reduceFunding(0, reduceAmount1);
      const project = await this.lido.projects(0);
      expect(project.currentAmount).to.equal(su("300"));
      await expect(this.lido.connect(this.signers.bob).reduceFunding(0, amount)).to.be.reverted;
    });
  });
});
