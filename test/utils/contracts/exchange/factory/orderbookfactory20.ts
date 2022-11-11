import { Contract, ContractTransaction } from "ethers";
import { ethers } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployOrderBookFactory20, deployOrderBookRouter20 } from "../../../../../tasks/deploy/deploy20";
import { readDeploymentsFile, writeDeploymentsFile } from "../../../../../tasks/utils";

export async function createBook20(
    hre: HardhatRuntimeEnvironment,
    nonce: number,
    tokenA: Contract, 
    tokenB: Contract,
    tokenAName: string,
    tokenBName: string,
    fee: number
) {
    let factory20Address = await readDeploymentsFile("OrderBookFactory20", hre.network.config.chainId);

    if(hre.network.config.chainId == 31337){
        const factory20 = await deployOrderBookFactory20(hre, nonce);
        factory20Address = factory20.address;
        nonce += 1;
        const router20 = await deployOrderBookRouter20(hre, nonce);
        nonce += 1;
    }
    let orderBookFactory20 = await hre.ethers.getContractAt("OrderBookFactory20", factory20Address);
    let signers = await hre.ethers.getSigners();
    let user = signers[0];
    let tx: ContractTransaction = await orderBookFactory20
            .connect(user)
            .createBook(tokenA.address,
                tokenB.address,
                fee,
                {gasLimit: 3000000});
    const receipt = await tx.wait();
    let book = await orderBookFactory20.getBook(
        tokenA.address,
        tokenB.address,
        fee
    );
    console.log("OrderBook20        deployed at", book);
    writeDeploymentsFile("OrderBook20", book, hre.network.config.chainId);
  
    return book;
}