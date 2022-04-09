import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Fixture } from "ethereum-waffle";

import type { Crowdfund } from "../src/types/contracts/Crowdfund";
import type { TestToken } from "../src/types/contracts/TestToken";

declare module "mocha" {
  export interface Context {
    cf: Crowdfund;
    tkn: TestToken;
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    signers: Signers;
  }
}

export interface Signers {
  admin: SignerWithAddress;
  signer1: SignerWithAddress;
  signer2: SignerWithAddress;
  signer3: SignerWithAddress;
  signer4: SignerWithAddress;
}
