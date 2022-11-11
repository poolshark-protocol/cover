import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ERC20, OrderBook20 } from "../../../../typechain";
import { task } from "hardhat/config";
import { getWalletAddress, getNonce, fundUser, readDeploymentsFile } from "../../../utils";
import { LIMIT_ORDER_1155_TO_20, LIMIT_ORDER_20 } from "../../../constants/taskNames";
import { Contract } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const { expect } = require("chai");

task(LIMIT_ORDER_1155_TO_20, "mint tokens for user")
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

  const orderBookAddress = await readDeploymentsFile("OrderBook1155To20", hre.network.config.chainId);

  const orderBookContract: Contract = await hre.ethers.getContractAt("OrderBook1155To20", orderBookAddress);

  const tokenA = await readDeploymentsFile("Token1155", hre.network.config.chainId);

  const tokenB = await readDeploymentsFile("Token20", hre.network.config.chainId);

  const tokenAContract: Contract = await hre.ethers.getContractAt("ERC1155", tokenA);

  const tokenBContract: Contract = await hre.ethers.getContractAt("ERC20", tokenB);

  let fromToken; let destToken;
  let fromDecimals; let destDecimals;

  if(args.fromtoken == "Token1155"){
    fromToken = tokenAContract.address;
    destToken = tokenBContract.address;
    fromDecimals = 0;
    destDecimals = await tokenBContract.decimals();
  }
  else {
    fromToken = tokenBContract.address;
    destToken = tokenAContract.address;
    fromDecimals = await tokenBContract.decimals();
    destDecimals = 0;
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
  const destAmount = hre.ethers.utils.parseUnits(args.destamount, destDecimals);

  await orderBookContract.limitOrder(
    fromToken,
    fromAmount,
    destAmount,
    false,
    true,
    {nonce: nonce}
  );
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

    const ret = await (await orderBook20.connect(user).limitOrder(
        fromToken.address,
        fromAmount,
        destAmount,
        false,
        false
      )).wait();

    expect(await fromTokenContract.balanceOf(user.address))
      .to.equal(preBal);

    return ret
  }

  