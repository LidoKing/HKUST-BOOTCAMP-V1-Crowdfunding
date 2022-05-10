import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { Lidogogo } from "../../src/types/contracts/Lidogogo";
import { Lidogogo__factory } from "../../src/types/factories/contracts/Lidogogo__factory";

task("deploy:Lidogogo")
  .addParam("tokenAddress", "Address of DAI")
  .addParam("poolAddress", "Address of Aave pool contract")
  .setAction(async function (taskArguments: TaskArguments, { ethers }) {
    const lidogogoFactory: Lidogogo__factory = <Lidogogo__factory>await ethers.getContractFactory("Lidogogo");
    const lidogogo: Lidogogo = <Lidogogo>(
      await lidogogoFactory.deploy(taskArguments.tokenAddress, taskArguments.poolAddress)
    );
    await lidogogo.deployed();
    console.log("Lidogogo deployed to: ", lidogogo.address);
  });
