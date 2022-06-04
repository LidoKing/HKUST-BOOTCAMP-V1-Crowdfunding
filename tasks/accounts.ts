import "@nomiclabs/hardhat-web3";
import { task } from "hardhat/config";

task("balance", "Prints an account's balance", async (_, { web3 }) => {
  const accounts = await web3.eth.getAccounts();

  for (let i = 0; i < 5; i++) {
    const balance = await web3.eth.getBalance(accounts[i]);
    const inEth = web3.utils.fromWei(balance, "ether");
    console.log(`${accounts[i]}: ${inEth}ETH`);
  }
});
