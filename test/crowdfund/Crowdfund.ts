import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
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

      const crowdfundArtifact: Artifact = await artifacts.readArtifact("Crowdfund");
      this.cf = <Crowdfund>await waffle.deployContract(this.signers.admin, crowdfundArtifact, [this.tkn.address]);
    });
  });
});
