import { Contract } from "ethers";
import { ethers } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { readDeploymentsFile } from "../../tasks/utils";

export async function createBook(
    hre: HardhatRuntimeEnvironment,
    tokenA: Contract, 
    tokenB: Contract,
    fee: number
) {
    const orderBookFactoryAddress = await readDeploymentsFile("OrderBookFactory", hre.network.config.chainId);

    let orderBookFactory = await ethers.getContractAt("OrderBookRouter", orderBookFactoryAddress);

    const ret = await (await orderBookFactory.createBook(
        tokenA.address,
        tokenB.address,
        fee
      )).wait();
  
      return ret
}