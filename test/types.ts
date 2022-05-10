import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Fixture } from "ethereum-waffle";

import type { Lidogogo } from "../src/types/contracts/Lidogogo";
import type { TestToken } from "../src/types/contracts/TestToken";

declare module "mocha" {
  export interface Context {
    lido: Lidogogo;
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
