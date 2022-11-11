import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ERC20, OrderBook20 } from "../../../../typechain";
import { task } from "hardhat/config";
import { getWalletAddress, getNonce, fundUser, readDeploymentsFile } from "../../../utils";
import { LIMIT_ORDER_20, QUOTE_OUT_20 } from "../../../constants/taskNames";
import { BigNumber, Contract } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const { expect } = require("chai");

task(LIMIT_ORDER_20, "mint tokens for user")
.addParam("fromtoken", "should be Token20A or Token20B")
.addParam("fromamount", "amount to transfer without decimals")
.addParam("destamount", "amount to transfer without decimals")
.addOptionalParam("makeronly", "bool to force maker order")
.addOptionalParam("takeronly", "bool to force taker order")
.setAction(async (args, hre) => {
  if(process.env.PRIVATE_KEY == undefined){
    return;
  }
  const accountAddress = await getWalletAddress(hre, process.env.PRIVATE_KEY);
  let nonce = await getNonce(hre, accountAddress);

  const orderBookAddress = await readDeploymentsFile("OrderBook20", hre.network.config.chainId);

  const orderBookContract: Contract = await hre.ethers.getContractAt("OrderBook20", orderBookAddress);

  const tokenA = await readDeploymentsFile("Token20A", hre.network.config.chainId);

  const tokenB = await readDeploymentsFile("Token20B", hre.network.config.chainId);

  const tokenAContract: Contract = await hre.ethers.getContractAt("ERC20", tokenA);

  const tokenBContract: Contract = await hre.ethers.getContractAt("ERC20", tokenB);

  let fromToken; let destToken;
  let fromDecimals; let destDecimals;
  if(args.fromtoken == "Token20A"){
    fromToken = tokenAContract.address;
    destToken = tokenBContract.address;
    fromDecimals = await tokenAContract.decimals();
    destDecimals = await tokenBContract.decimals();
  }
  else {
    fromToken = tokenBContract.address;
    destToken = tokenAContract.address;
    fromDecimals = await tokenBContract.decimals();
    destDecimals = await tokenAContract.decimals();
  }
  let makerOnly; let takerOnly;
  if(args.makerOnly == "true"){
    makerOnly = true;
    takerOnly = false;
  }
  else if(args.takerOnly == "true"){
    makerOnly = false;
    takerOnly = true;
  }
  else {
    makerOnly = false;
    takerOnly = false;
  }

  const fromAmount = hre.ethers.utils.parseUnits(args.fromamount, 0);
  const destAmount = hre.ethers.utils.parseUnits(args.destamount, 0);

  await orderBookContract.limitOrder(
    fromToken,
    fromAmount,
    destAmount,
    BigNumber.from("0"),
    makerOnly,
    takerOnly,
    {nonce: nonce, gasLimit: 300000}
  );
});

task(QUOTE_OUT_20, "quote for orderbook20")
.addParam("fromtoken", "should be Token20A or Token20B")
.addParam("fromamount", "amount to transfer without decimals")
.addParam("limitprice", "page price to buy up to")
.setAction(async (args, hre) => {
  if(process.env.PRIVATE_KEY == undefined){
    return;
  }
  const accountAddress = await getWalletAddress(hre, process.env.PRIVATE_KEY);
  let nonce = await getNonce(hre, accountAddress);

  const orderBookAddress = await readDeploymentsFile("OrderBook20", hre.network.config.chainId);

  const orderBookContract: Contract = await hre.ethers.getContractAt("OrderBook20", orderBookAddress);

  const tokenA = await readDeploymentsFile("Token20A", hre.network.config.chainId);
  const tokenB = await readDeploymentsFile("Token20B", hre.network.config.chainId);
  const tokenAContract: Contract = await hre.ethers.getContractAt("ERC20", tokenA);
  const tokenBContract: Contract = await hre.ethers.getContractAt("ERC20", tokenB);

  let fromToken; let destToken;
  let fromDecimals; let destDecimals;

  if(args.fromtoken == "Token20A"){
    fromToken = tokenAContract.address;
    destToken = tokenBContract.address;
    fromDecimals = await tokenAContract.decimals();
    destDecimals = await tokenBContract.decimals();
  }
  else {
    fromToken = tokenBContract.address;
    destToken = tokenAContract.address;
    fromDecimals = await tokenBContract.decimals();
    destDecimals = await tokenAContract.decimals();
  }
  let makerOnly; let takerOnly;
  if(args.makerOnly == "true"){
    makerOnly = true;
    takerOnly = false;
  }
  else if(args.takerOnly == "true"){
    makerOnly = false;
    takerOnly = true;
  }
  else {
    makerOnly = false;
    takerOnly = false;
  }
  const fromAmount = hre.ethers.utils.parseUnits(args.fromamount, fromDecimals);

  const quote = await orderBookContract.quoteExactAmountOut(
    fromToken,
    fromAmount,
    args.limitprice,
    {nonce: nonce, gasLimit: 30000000}
  );

  // const pageKey = ethers.utils.formatBytes32String("0x4b0964dab05fd855511edf41ef8778147f48336d003de9d3de0d963e6708afb4")

  console.log((await orderBookContract.pages("0x4b0964dab05fd855511edf41ef8778147f48336d003de9d3de0d963e6708afb4")).price.toString());
  const multiplier = ethers.utils.parseUnits("1",18);
  console.log("fromAmountIn: ",  quote[0].toString());
  console.log("destAmountOut:", quote[1].toString());
  console.log("firstPageInBook0:", await orderBookContract.firstPageInBook0());
  console.log("firstPageInBook1:", await orderBookContract.firstPageInBook1());
});

export async function limitOrder20(
    hre: HardhatRuntimeEnvironment,
    user: SignerWithAddress,
    fromToken: ERC20, 
    destToken: ERC20,
    fee: number, 
    fromAmount: number, 
    destAmount: number,
    orderBook20: OrderBook20
  ) {
    let fromTokenContract = await hre.ethers.getContractAt("ERC20", fromToken.address);

    const preBal = await fromTokenContract.balanceOf(user.address)
    await fundUser(hre, fromToken, user, fromAmount);

    await fromTokenContract
      .connect(user)
      .approve(orderBook20.address, fromAmount);

    // const ret = await (await orderBook20.connect(user).limitOrder(
    //     fromToken.address,
    //     fromAmount,
    //     destAmount,
    //     0m
    //     false,
    //     false
    //   )).wait();

    // expect(await fromTokenContract.balanceOf(user.address))
    //   .to.equal(preBal);

    // return ret
  }

  