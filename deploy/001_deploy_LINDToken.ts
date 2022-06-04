import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer, lindOwner } = await getNamedAccounts();

  await deploy("LINDToken", {
    from: deployer,
    args: [lindOwner],
    log: true,
  });
};
export default func;
func.tags = ["LINDToken"];
