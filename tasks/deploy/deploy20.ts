import { BigNumber, BigNumberish, Contract } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { readDeploymentsFile, writeDeploymentsFile } from "../utils";

export async function deployOrderBookFactory20(
  hre: HardhatRuntimeEnvironment,
  nonce: number
): Promise<Contract> {
  const OrderBookFactory = await hre.ethers.getContractFactory("OrderBookFactory20");
  const orderBookFactory = await OrderBookFactory.deploy({ nonce });
  writeDeploymentsFile(
    "OrderBookFactory20",
    orderBookFactory.address,
    hre.network.config.chainId
  );
  console.log("OrderBookFactory20 deployed at", orderBookFactory.address);

  return orderBookFactory;
}

export async function deployOrderBookRouter20(
  hre: HardhatRuntimeEnvironment,
  nonce: number
): Promise<Contract> {
  let orderBookFactory20Address = await readDeploymentsFile("OrderBookFactory20", hre.network.config.chainId);
  if(orderBookFactory20Address == ""){
    const orderBookFactory20 = await deployOrderBookFactory20(hre, nonce);
    orderBookFactory20Address = orderBookFactory20.address;
    nonce += 1;
  }
  const orderBookRouter20Factory = await hre.ethers.getContractFactory("OrderBookRouter20");
  const orderBookRouter20 = await orderBookRouter20Factory.deploy(orderBookFactory20Address, { nonce });
  writeDeploymentsFile(
    "OrderBookRouter20",
    orderBookRouter20.address,
    hre.network.config.chainId
  );
  console.log("OrderBookRouter20  deployed at", orderBookRouter20.address);

  return orderBookRouter20;
}

export async function deployOrderBook20(
    hre: HardhatRuntimeEnvironment,
    nonce: number,
    token0: string,
    token1: string,
    fee: BigNumberish
  ): Promise<Contract> {
    const OrderBook = await hre.ethers.getContractFactory("OrderBook20");
    const orderBook = await OrderBook.deploy(token0, token1, fee, { nonce });
    writeDeploymentsFile(
      "OrderBook20",
      orderBook.address,
      hre.network.config.chainId
    );
    console.log("OrderBook20        deployed at", orderBook.address);
  
    return orderBook;
  }

  export async function deployToken20(
    hre: HardhatRuntimeEnvironment,
    nonce: number,
    name: string,
    symbol: string,
    decimals: BigNumberish
  ): Promise<Contract> {
    const Token = await hre.ethers.getContractFactory("Token20");
    const token = await Token.deploy(
      name,
      symbol,
      decimals,
      {nonce: nonce}
    );
    writeDeploymentsFile(
      name,
      token.address,
      hre.network.config.chainId
    );
    console.log(name, "         deployed at", token.address);
  
    return token;
  }