import { BigNumber, BigNumberish, Contract } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { readDeploymentsFile, writeDeploymentsFile } from "../utils";

export async function deployOrderBookFactory1155To20(
  hre: HardhatRuntimeEnvironment,
  nonce: number
): Promise<Contract> {
  const OrderBookFactory = await hre.ethers.getContractFactory("OrderBookFactory1155To20");
  const orderBookFactory = await OrderBookFactory.deploy({ nonce });
  writeDeploymentsFile(
    "OrderBookFactory1155To20",
    orderBookFactory.address,
    hre.network.config.chainId
  );
  console.log("OrderBookFactory1155To20 deployed at", orderBookFactory.address);

  return orderBookFactory;
}

export async function deployOrderBookRouter1155To20(
  hre: HardhatRuntimeEnvironment,
  nonce: number
): Promise<Contract> {
  let orderBookFactoryAddress = await readDeploymentsFile("OrderBookFactory1155To20", hre.network.config.chainId);
  if(orderBookFactoryAddress == ""){
    const orderBookFactory = await deployOrderBookFactory1155To20(hre, nonce);
    orderBookFactoryAddress = orderBookFactory.address;
    nonce += 1;
  }
  const orderBookRouterFactory = await hre.ethers.getContractFactory("OrderBookRouter1155To20");
  const orderBookRouter = await orderBookRouterFactory.deploy(orderBookFactoryAddress, { nonce });
  writeDeploymentsFile(
    "OrderBookRouter1155To20",
    orderBookRouter.address,
    hre.network.config.chainId
  );
  console.log("OrderBookRouter1155To20  deployed at", orderBookRouter.address);

  return orderBookRouter;
}

export async function deployOrderBook1155To20(
    hre: HardhatRuntimeEnvironment,
    nonce: number,
    token0: string,
    token1: string,
    token0id: string,
    fee: BigNumberish
  ): Promise<Contract> {
    const OrderBook = await hre.ethers.getContractFactory("OrderBook1155To20");
    const orderBook = await OrderBook.deploy(token0, token1, fee, token0id, { nonce });
    writeDeploymentsFile(
      "OrderBook1155To20",
      orderBook.address,
      hre.network.config.chainId
    );
    console.log("OrderBook1155To20        deployed at", orderBook.address);
  
    return orderBook;
  }

  export async function deployToken1155(
    hre: HardhatRuntimeEnvironment,
    nonce: number,
    name: string,
    symbol: string,
    decimals: BigNumberish
  ): Promise<Contract> {
    const Token = await hre.ethers.getContractFactory("Token1155");
    const token = await Token.deploy(
      name,
      {nonce: nonce}
    );
    writeDeploymentsFile(
      name,
      token.address,
      hre.network.config.chainId
    );
    console.log(name, "        deployed at", token.address);
  
    return token;
  }